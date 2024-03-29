FROM tomcat:9-jre11

MAINTAINER Oscar Fonts <oscar.fonts@geomati.co>

ENV GEOSERVER_VERSION 2.15.2
ENV GEOSERVER_DATA_DIR /var/local/geoserver
ENV GEOSERVER_INSTALL_DIR /usr/local/geoserver

# Uncomment to use APT cache (requires apt-cacher-ng on host)
#RUN echo "Acquire::http { Proxy \"http://`/sbin/ip route|awk '/default/ { print $3 }'`:3142\"; };" > /etc/apt/apt.conf.d/71-apt-cacher-ng

# Microsoft fonts
RUN echo "deb http://httpredir.debian.org/debian stretch contrib" >> /etc/apt/sources.list
RUN set -x \
	&& apt-get update \
	&& apt-get install -yq ttf-mscorefonts-installer \
	&& rm -rf /var/lib/apt/lists/*
	
# Native JAI & ImageIO
RUN cd /usr/lib/jvm/java-11-openjdk-amd64 \
	&& wget http://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64-jdk.bin \
	&& tail -n +139 jai-1_1_3-lib-linux-amd64-jdk.bin > INSTALL-jai \
	&& chmod u+x INSTALL-jai \
	&& ./INSTALL-jai \
	&& rm jai-1_1_3-lib-linux-amd64-jdk.bin INSTALL-jai *.txt \
	&& wget http://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64-jdk.bin \
	&& tail -n +215 jai_imageio-1_1-lib-linux-amd64-jdk.bin > INSTALL-jai_imageio \
	&& chmod u+x INSTALL-jai_imageio \
	&& ./INSTALL-jai_imageio \
	&& rm jai_imageio-1_1-lib-linux-amd64-jdk.bin INSTALL-jai_imageio *.txt

# GeoServer
ADD conf/geoserver.xml /usr/local/tomcat/conf/Catalina/localhost/geoserver.xml
RUN mkdir ${GEOSERVER_DATA_DIR} \
	&& mkdir ${GEOSERVER_INSTALL_DIR} \
	&& cd ${GEOSERVER_INSTALL_DIR} \
	&& wget http://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/geoserver-${GEOSERVER_VERSION}-war.zip \
	&& unzip geoserver-${GEOSERVER_VERSION}-war.zip \
	&& unzip geoserver.war \
	&& mv data/* ${GEOSERVER_DATA_DIR} \
	&& rm -rf geoserver-${GEOSERVER_VERSION}-war.zip geoserver.war target *.txt

# Enable CORS
RUN sed -i '\:</web-app>:i\
<filter>\n\
    <filter-name>CorsFilter</filter-name>\n\
    <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>\n\
    <init-param>\n\
        <param-name>cors.allowed.origins</param-name>\n\
        <param-value>*</param-value>\n\
    </init-param>\n\
    <init-param>\n\
	<param-name>cors.allowed.methods</param-name>\n\
	<param-value>GET,POST,HEAD,OPTIONS,PUT</param-value>\n\
    </init-param>\n\
    <init-param>\n\
	<param-name>cors.allowed.headers</param-name>\n\
	<param-value>Content-Type,X-Requested-With,accept,Origin,Access-Control-Request-Method,Access-Control-Request-Headers,Authorization</param-value>\n\
    </init-param>\n\
    <init-param>\n\
	<param-name>cors.exposed.headers</param-name>\n\
	<param-value>Access-Control-Allow-Origin,Access-Control-Credentials,Authorization</param-value>\n\
    </init-param>\n\
</filter>\n\
<filter-mapping>\n\
    <filter-name>CorsFilter</filter-name>\n\
    <url-pattern>/*</url-pattern>\n\
</filter-mapping>' ${GEOSERVER_INSTALL_DIR}/WEB-INF/web.xml

# DDS plugin
ADD dds.zip /usr/local/geoserver/WEB-INF/lib/dds.zip
RUN unzip -qo /usr/local/geoserver/WEB-INF/lib/dds.zip -d /usr/local/geoserver/WEB-INF/lib/

# gdal plugin
ADD gdal.zip /usr/local/geoserver/WEB-INF/lib/gdal.zip
RUN unzip -qo /usr/local/geoserver/WEB-INF/lib/gdal.zip -d /usr/local/geoserver/WEB-INF/lib/

ENV GDAL_DATA $CATALINA_HOME/gdal-data
ENV LD_LIBRARY_PATH $JAVA_HOME/jre/lib/amd64/gdal
ADD gdal-data.zip /usr/local/gdal-data.zip
ADD gdal192-Ubuntu12-gcc4.6.3-x86_64.zip /usr/local/gdal192-Ubuntu12-gcc4.6.3-x86_64.zip
RUN unzip /usr/local/gdal-data.zip -d $CATALINA_HOME && \
    mkdir $JAVA_HOME/jre/lib/amd64/gdal
	
RUN unzip /usr/local/gdal192-Ubuntu12-gcc4.6.3-x86_64.zip -d $LD_LIBRARY_PATH;


# Tomcat environment
ENV CATALINA_OPTS "-server -Djava.awt.headless=true \
	-Xms768m -Xmx1560m -XX:+UseConcMarkSweepGC -XX:NewSize=48m \
	-DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR}"

ADD start.sh /usr/local/bin/start.sh
CMD start.sh

EXPOSE 8080