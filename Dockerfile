FROM bitnami/git AS fetcher
ARG NAME
RUN git clone --depth 1 https://github.com/outsideworx/${NAME}.git /site

FROM httpd:2.4
ARG NAME
ARG TOKEN
ENV NAME=${NAME}
COPY --from=fetcher /site /usr/local/apache2/htdocs/

RUN sed -i \
    -e 's|#LoadModule headers_module modules/mod_headers.so|LoadModule headers_module modules/mod_headers.so|' \
    -e 's|#LoadModule negotiation_module modules/mod_negotiation.so|LoadModule negotiation_module modules/mod_negotiation.so|' \
    -e 's|#LoadModule proxy_module modules/mod_proxy.so|LoadModule proxy_module modules/mod_proxy.so|' \
    -e 's|#LoadModule proxy_http_module modules/mod_proxy_http.so|LoadModule proxy_http_module modules/mod_proxy_http.so|' \
    -e 's|#LoadModule ratelimit_module modules/mod_ratelimit.so|LoadModule ratelimit_module modules/mod_ratelimit.so|' \
    -e 's|#LoadModule reqtimeout_module modules/mod_reqtimeout.so|LoadModule reqtimeout_module modules/mod_reqtimeout.so|' \
    -e 's|#LoadModule ssl_module modules/mod_ssl.so|LoadModule ssl_module modules/mod_ssl.so|' \
    -e 's|#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so|LoadModule socache_shmcb_module modules/mod_socache_shmcb.so|' \
    -e 's|#LoadModule unique_id_module modules/mod_unique_id.so|LoadModule unique_id_module modules/mod_unique_id.so|' \
    -e '/^Listen 80/d' \
    -e '$aInclude conf/extra/httpd-logs.conf' \
    -e '$aInclude conf/extra/httpd-metrics.conf' \
    -e '$aInclude conf/extra/httpd-proxy.conf' \
    -e '$aInclude conf/extra/httpd-ssl.conf' \
    -e '$aServerName sites.outsideworx.net' \
    conf/httpd.conf

RUN find conf -type f -name '*.conf' -exec sed -i -E \
    -e '/^[[:space:]]*CustomLog([[:space:]]|\\)/,/[^\\]$/d' \
    -e '/^[[:space:]]*ErrorLog/d' \
    -e '/^[[:space:]]*TransferLog/d' {} +

RUN cat <<EOF > conf/extra/httpd-logs.conf
ErrorLogFormat "ERROR %P --- requestId=%{UNIQUE_ID}e ip=%a: %M"
ErrorLog |/usr/local/bin/send-to-loki.sh
LogFormat " INFO %P --- requestId=%{UNIQUE_ID}e ip=%a: %r %>s" log_format
SetEnvIf Request_URI "^/metrics$" no_log
CustomLog |/usr/local/bin/send-to-loki.sh log_format env=!no_log
EOF

RUN cat <<'EOF' > /usr/local/bin/send-to-loki.sh
#!/bin/sh
while read -r line; do
    timestamp=$(($(date +%s) * 1000000000))
    json="{\"streams\":[{\"stream\":{\"app\":\"${NAME}\",\"job\":\"sites\"},\"values\":[[\"$timestamp\",\"$line\"]]}]}"
    curl -s -X POST -H "Content-Type: application/json" -d "$json" http://loki:3100/loki/api/v1/push
done
EOF
RUN apt update -qq && apt install -y curl; \
    chmod +x /usr/local/bin/send-to-loki.sh

RUN cat <<EOF > conf/extra/httpd-metrics.conf
Listen 80
<VirtualHost *:80>
    DocumentRoot "/usr/local/apache2/htdocs"
    <LocationMatch "^(?!/metrics)$">
        Require all denied
    </LocationMatch>
</VirtualHost>
EOF

RUN cat <<EOF > conf/extra/httpd-proxy.conf
ProxyRequests Off
ProxyPreserveHost On
SSLProxyEngine On
SSLProxyVerify none
SSLProxyCheckPeerName off
ProxyPass        "/api/"  "https://vault/api/"
ProxyPassReverse "/api/"  "https://vault/api/"
<IfModule mod_headers.c>
    RequestHeader set X-Auth-Token "${TOKEN}"
    RequestHeader set X-Caller-Id "${NAME}"
    RequestHeader set X-Request-Id "%{UNIQUE_ID}e"
    Header always set X-Request-Id "%{UNIQUE_ID}e"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Content-Security-Policy "         \
        base-uri          'none';                       \
        connect-src       'self';                       \
        default-src       'none';                       \
        font-src            *        https:;            \
        frame-ancestors   'none';                       \
        frame-src           *        https:;            \
        form-action       'self';                       \
        img-src           'self'     data:;             \
        media-src           *        https:;            \
        script-src          *       'unsafe-inline';    \
        style-src           *       'unsafe-inline';"
</IfModule>
<IfModule mod_alias.c>
    RedirectMatch 301 ^/grafana(/.*)?$  https://services.outsideworx.net/grafana$1
    RedirectMatch 301 ^/login(/.*)?$    https://services.outsideworx.net/login$1
    RedirectMatch 301 ^/ntfy(/.*)?$     https://services.outsideworx.net/ntfy$1
    RedirectMatch 403 /\.
    RedirectMatch 403 \.(conf|config|log|properties|php|py|sh|ts|yaml|yml)/?$
    RedirectMatch 403 ^(?!/(metrics|robots)\.txt$).*\.txt$
    RedirectMatch 403 ^(?!/(sitemap)\.xml$).*\.xml/?$
</IfModule>
<IfModule mod_ratelimit.c>
    SetOutputFilter RATE_LIMIT
    SetEnv rate-limit 1536
</IfModule>
<IfModule mpm_event_module>
    MaxRequestWorkers 100
</IfModule>
<IfModule reqtimeout_module>
    RequestReadTimeout header=2-5,MinRate=2048 body=5-30,MinRate=4096
</IfModule>
<Directory "/usr/local/apache2/htdocs">
    Options +MultiViews
</Directory>
EOF

RUN sed -i \
    -e 's|^ServerName.*|ServerName sites.outsideworx.net|' \
    -e 's|^SSLCertificateFile.*|SSLCertificateFile "/usr/local/apache2/conf/fullchain.pem"|' \
    -e 's|^SSLCertificateKeyFile.*|SSLCertificateKeyFile "/usr/local/apache2/conf/privkey.pem"|' \
    -e '/<\/VirtualHost>/i <Location "/metrics.txt">\nRequire all denied\n</Location>' \
    conf/extra/httpd-ssl.conf

EXPOSE 80 443
CMD ["httpd-foreground"]