FROM opensourcery/debian:buster-slim
LABEL maintainer "open.source@opensourcery.uk"

ENv DEBIAN_FRONTEND noninteractive

RUN apt-get update \
 && apt-get dist-upgrade -y \
 && apt-get install -y samba attr \
 && apt-get install -y winbind libpam-winbind libnss-winbind libpam-krb5 krb5-config krb5-user xattr libbsd-dev iproute2 \
 && apt-get install -y bind9 dnsutils \
 && apt-get install -y supervisor

RUN rm /etc/samba/smb.conf \
 && echo 'include "/var/lib/samba/bind-dns/named.conf";' >> /etc/bind/named.conf \
 && sed -i 's/^};/\ttkey-gssapi-keytab "\/var\/lib\/samba\/bind-dns\/dns.keytab";\n};/' /etc/bind/named.conf.options

RUN echo "logging {\n\
  channel default_stderr {\n\
    stderr;\n\
    severity debug;\n\
    print-category yes;\n\
    print-time yes;\n\
  };\n\
  category default{\n\
    default_stderr;\n\
  };\n\
};" >> /etc/bind/named.conf.local

ADD supervisord-samba /etc/supervisor/conf.d/samba.conf
ADD supervisord-bind /etc/supervisor/conf.d/bind.conf

ADD entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

EXPOSE 53/udp 53 389 88 135 139 138 445 464 636 3268 3269

ENTRYPOINT ["/entrypoint.sh"]
