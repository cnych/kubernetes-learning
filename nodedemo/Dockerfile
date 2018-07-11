FROM node:slim

RUN mkdir /app
WORKDIR /app

ONBUILD COPY ./package.json /app
ONBUILD RUN npm install
ONBUILD COPY . /app

CMD ["npm", "start"]