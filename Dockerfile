# For Alpine 3.10:
FROM sebp/elk:793

# # Download certificate and key from the customer portal (https://my.f5.com)
# # and copy to the build context:
# COPY license/nginx-repo.key /etc/apk/cert.key
# COPY license/nginx-repo.crt /etc/apk/cert.pem

# # Download and add the NGINX signing key:
# RUN wget -O /etc/apk/keys/nginx_signing.rsa.pub https://cs.nginx.com/static/keys/nginx_signing.rsa.pub

# # Download and add the security updates signing key:
# RUN wget -O /etc/apk/keys/app-protect-security-updates.rsa.pub https://cs.nginx.com/static/keys/app-protect-security-updates.rsa.pub

# # Add NGINX Plus repository:
# RUN printf "https://plus-pkgs.nginx.com/alpine/v`egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release`/main\n" | tee -a /etc/apk/repositories

# # Add security updates repository
# RUN printf "https://app-protect-security-updates.nginx.com/alpine/v`egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release`/main\n" | tee -a /etc/apk/repositories

# # Update the repository and install the most recent version of the NGINX App Protect package (which includes NGINX Plus):
# RUN apk update && apk add bash curl jq
# RUN apk add app-protect-compiler
# RUN apk add app-protect-attack-signatures
# # RUN apk add app-protect-attack-signatures=2020.12.28-r1

# # Remove nginx repository key/cert from docker
# RUN rm -rf /etc/apk/cert.*

# COPY ./convert.sh convert.sh
# COPY ./signature-report.sh signature-report.sh
