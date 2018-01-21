FROM alpine:3.7

RUN set -x \
 && apk add --no-cache \
        ca-certificates \
        duplicity \
        lftp \
        openssh \
        openssl \
        py-crypto \
        py-pip \
        py-paramiko \
        py-setuptools \
        rsync \
        bash \
 && update-ca-certificates \
 && pip install \
      pydrive==1.3.1 \
      fasteners==0.14.1 \
      boto3==1.5.8 \
 && apk del --purge py-pip

VOLUME ["/root/.cache/duplicity", "/root/.gnupg"]

#FROM ubuntu

#RUN apt-get update
#RUN apt-get install -y \
#    duplicity \
#    python-boto

# See inside settings.sh for instructions on what to put in 
# mysettings.sh
COPY ./settings.sh ./mysettings.sh ./backup-peecloud-to-aws.sh /

ENTRYPOINT ["/backup-peecloud-to-aws.sh"]
CMD ["--weekly-backup"]
