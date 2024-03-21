#!/usr/bin/env bash
set -e

case $(uname -m) in
    arm64)   url="https://cdn.azul.com/zulu/bin/zulu21.28.89-ca-crac-jdk21.0.0-linux_aarch64.tar.gz" ;;
    *)       url="https://cdn.azul.com/zulu/bin/zulu21.28.89-ca-crac-jdk21.0.0-linux_x64.tar.gz" ;;
esac

echo "Using CRaC enabled JDK $url"
docker build -t chatbot-crac:builder -f Dockerfile.CRAC --build-arg CRAC_JDK_URL=$url .
docker run -d --privileged --rm --name=chatbot-crac --ulimit nofile=1024 -p 8080:8080 -v $(pwd)/target:/opt/mnt -e FLAG=$1 chatbot-crac:builder
echo "Please wait during checkpoint creation..."
sleep 10
docker commit --change='ENTRYPOINT ["/opt/app/entrypoint.sh"]' $(docker ps -qf "name=chatbot-crac") chatbot-crac:0.0.1
docker kill $(docker ps -qf "name=chatbot-crac")