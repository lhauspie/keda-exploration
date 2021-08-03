FROM ubuntu:20.04
MAINTAINER Logan HAUSPIE

RUN apt-get update
RUN apt-get install -y postgresql-client
RUN apt-get upgrade -y bash
RUN apt-get install -y telnet

RUN mkdir /home/app
WORKDIR /home/app

COPY entrypoint.sh ./
COPY scripts/ ./scripts/

RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]