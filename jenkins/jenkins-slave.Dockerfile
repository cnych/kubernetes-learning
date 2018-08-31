FROM debian:stretch

ENV JAVA_HOME=/usr/local/newhope/java1.8 \
    PATH=/usr/local/newhope/java1.8/bin:$PATH \
    TIMEZONE=Asia/Shanghai \
    LANG=zh_CN.UTF-8

RUN echo "${TIMEZONE}" > /etc/timezone \
    && echo "$LANG UTF-8" > /etc/locale.gen \
    && apt-get update -q \
    && ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && mkdir -p /usr/local/newhope/java1.8 \
    && mkdir -p /home/jenkins/.jenkins \
    && mkdir -p /home/jenkins/agent \
    && mkdir -p /usr/share/jenkins \
    && mkdir -p /root/.kube

COPY java1.8 /usr/local/newhope/java1.8
COPY kubectl /usr/local/bin/kubectl
COPY jenkins-slave /usr/local/bin/jenkins-slave
COPY slave.jar /usr/share/jenkins

# java/字符集/DinD/svn/jnlp
RUN  mkdir /usr/java/jdk1.8.0_121/bin -p \
     && ln -s /usr/local/newhope/java1.8 /usr/java/jdk1.8.0_121 \
     && DEBIAN_FRONTEND=noninteractive apt-get install -yq curl apt-utils dialog locales  apt-transport-https build-essential bzip2 ca-certificates  sudo jq unzip zip gnupg2 software-properties-common \
     && update-locale LANG=$LANG \
     && locale-gen $LANG \
     && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales \
     &&curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg |apt-key add - \
     && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable" \
     && apt-get update -y \
     && apt-get install -y docker-ce=17.09.1~ce-0~debian \
     && sudo apt-get install -y subversion \
     && groupadd -g 10000 jenkins \
     && useradd -c "Jenkins user" -d $HOME -u 10000 -g 10000 -m jenkins \
     && usermod -a -G docker jenkins \
     && sed -i '/^root/a\jenkins    ALL=(ALL:ALL) NOPASSWD:ALL' /etc/sudoers

USER root

WORKDIR /home/jenkins

ENTRYPOINT ["jenkins-slave"]
