FROM nginx:stable-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html style.css /usr/share/nginx/html/
COPY js/ /usr/share/nginx/html/js/
COPY assets/art/palace/palace-hires.png assets/art/palace/palace-sprite.js /usr/share/nginx/html/assets/art/palace/
COPY assets/art/buildings/*.png assets/art/buildings/buildings-sprites.js /usr/share/nginx/html/assets/art/buildings/

COPY assets/art/units/*.png assets/art/units/units-sprites.js /usr/share/nginx/html/assets/art/units/

EXPOSE 8080
