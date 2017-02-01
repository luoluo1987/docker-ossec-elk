FROM phusion/baseimage:0.9.15
MAINTAINER Jingxuan <jingxus@g.clemson.edu>

# Update repositories, install git, gcc, wget, make and java8 and
# clone down the latest OSSEC build from the official Github repo.
RUN apt-get update && apt-get install -y curl && curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
RUN apt-get install -y nodejs
RUN apt-get update && apt-get install -y python-software-properties debconf-utils daemontools wget
RUN add-apt-repository -y ppa:webupd8team/java &&\
    apt-get update &&\
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections &&\
    apt-get -yf install oracle-java8-installer

RUN apt-get update && apt-get install -y vim expect gcc make libssl-dev unzip

RUN cd root && mkdir ossec_tmp && cd ossec_tmp

# Copy the unattended installation config file from the build context
# and put it where the OSSEC install script can find it. Then copy the
# process. Then run the install script, which will turn on just about
# everything except e-mail notifications


RUN wget https://github.com/wazuh/wazuh/archive/master.zip &&\
    tar xvfz master.zip &&\
    mv wazuh-master /root/ossec_tmp/ossec-wazuh &&\
    rm master.zip
#ADD ossec-wazuh /root/ossec_tmp/ossec-wazuh
COPY preloaded-vars.conf /root/ossec_tmp/ossec-wazuh/etc/preloaded-vars.conf

RUN /root/ossec_tmp/ossec-wazuh/install.sh

RUN apt-get remove --purge -y gcc make && apt-get clean

# Set persistent volumes for the /etc and /log folders so that the logs
# and agent keys survive a start/stop and expose ports for the
# server/client ommunication (1514) and the syslog transport (514)

ADD default_agent /var/ossec/default_agent
RUN service ossec restart &&\
  /var/ossec/bin/manage_agents -f /default_agent &&\
  rm /var/ossec/default_agent &&\
  service ossec stop &&\
  echo -n "" /var/ossec/logs/ossec.log

ADD data_dirs.env /data_dirs.env
ADD init.bash /init.bash
# Sync calls are due to https://github.com/docker/docker/issues/9547
RUN chmod 755 /init.bash &&\
  sync && /init.bash &&\
  sync && rm /init.bash


ADD run.sh /tmp/run.sh
RUN chmod 755 /tmp/run.sh

VOLUME ["/var/ossec/data"]

EXPOSE 1514/udp 1515/tcp 514/udp

# Run supervisord so that the container will stay alive

ENTRYPOINT ["/tmp/run.sh"]
