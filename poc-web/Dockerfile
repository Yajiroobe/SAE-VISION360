FROM nginx:alpine
RUN apk add --no-cache curl
WORKDIR /usr/share/nginx/html
COPY index.html ./
RUN mkdir -p vendor \
 && curl -fsSL -o vendor/tf.min.js https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.12.0/dist/tf.min.js \
 && curl -fsSL -o vendor/coco-ssd.min.js https://cdn.jsdelivr.net/npm/@tensorflow-models/coco-ssd@2.2.2
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

