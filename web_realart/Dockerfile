FROM node:22-alpine

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./
COPY public ./public

EXPOSE 4400
ENV HTTP_PORT=4400
ENV DATA_PORT_IN=57124

# UDP 57124 doit etre exposable (data_feeds bridge.py emet ici)
# docker run -p 4400:4400 -p 57124:57124/udp av-live-realart

CMD ["node", "server.js"]
