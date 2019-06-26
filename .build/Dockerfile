FROM node:10-alpine

# This shit is supposed to install python
RUN apk --no-cache add git g++ gcc libgcc libstdc++ linux-headers make python

WORKDIR /opt/app

COPY package.json ./
RUN npm config set unsafe-perm true
RUN npm install -g truffle
RUN npm install -g yarn
COPY . .
