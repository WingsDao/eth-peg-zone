FROM node:10-alpine

# This shit is supposed to install python
RUN apk --no-cache add bash git g++ gcc libgcc libstdc++ linux-headers make python

WORKDIR /opt/app

COPY package.json ./
RUN npm config set unsafe-perm true && \
    npm install -g truffle && \
    yarn install

COPY . .
COPY .build/run.sh /

CMD ["/run.sh"]
