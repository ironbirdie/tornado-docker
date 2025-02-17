FROM centos:7

# epel for cabextract
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 \
    && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 \
    && yum install -y --setopt=tsflags=nodocs \
    java-1.8.0-openjdk \
    #
    # libreoffice requirements
    cairo \
    cups-libs \
    dbus-glib \
    glib2 \
    libSM \
    libXinerama \
    mesa-libGL \
    #
    # extra fonts
    open-sans-fonts \
    gnu-free-mono-fonts \
    gnu-free-sans-fonts \
    gnu-free-serif-fonts \
    #
    # mscorefonts dependencies
    cabextract \
    curl \
    #
    # utilities
    unzip \
    wget \
    #
    && yum clean all \
    && rm -rf /var/cache/yum

RUN yum install -y https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm \
    && yum clean all \
    && rm -rf /var/cache/yum

ENV LIBREOFFICE_VERSION=7.1.2.2
ENV LIBREOFFICE_MIRROR=https://downloadarchive.documentfoundation.org/libreoffice/old/

RUN echo "Downloading LibreOffice ${LIBREOFFICE_VERSION}..." \
    && echo ${LIBREOFFICE_MIRROR}${LIBREOFFICE_VERSION}/rpm/x86_64/LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_rpm.tar.gz \
    && wget --quiet ${LIBREOFFICE_MIRROR}${LIBREOFFICE_VERSION}/rpm/x86_64/LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_rpm.tar.gz \
    && tar -xf LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_rpm.tar.gz \
    && cd LibreOffice_*_Linux_x86-64_rpm/RPMS \
    && (rm -f *integ* || true) \
    && (rm -f *desk* || true) \
    && yum localinstall -y --setopt=tsflags=nodocs *.rpm \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && cd ../.. \
    && rm -rf LibreOffice_*_Linux_x86-64_rpm \
    && rm -f LibreOffice_*_Linux_x86-64_rpm.tar.gz \
    && ln -s /opt/libreoffice* /opt/libreoffice

RUN groupadd docmosis \
    && useradd -g docmosis \
    --create-home \
    --shell /sbin/nologin \
    --comment "Docmosis user" \
    docmosis

WORKDIR /home/docmosis

ENV DOCMOSIS_VERSION=2.8.3

RUN DOCMOSIS_VERSION_SHORT=$(echo $DOCMOSIS_VERSION | cut -f1 -d_) \
    && echo "Downloading Docmosis Tornado ${DOCMOSIS_VERSION}..." \
    && echo https://resources.docmosis.com/Downloads/Tornado/${DOCMOSIS_VERSION_SHORT}/docmosisTornado${DOCMOSIS_VERSION}.zip \
    && wget --quiet https://resources.docmosis.com/Downloads/Tornado/${DOCMOSIS_VERSION_SHORT}/docmosisTornado${DOCMOSIS_VERSION}.zip \
    && unzip docmosisTornado${DOCMOSIS_VERSION}.zip docmosisTornado*.war docs/* licenses/* \
    && mv docmosisTornado*.war docmosisTornado.war \
    && rm -f docmosisTornado${DOCMOSIS_VERSION}.zip

# mscorefonts2 does not currently install cambria.ttc
RUN echo "Downloading Cambria font collection..." \
    && wget --quiet -O PowerPointViewer.exe http://downloads.sourceforge.net/mscorefonts2/PowerPointViewer.exe \
    && cabextract --lowercase -F 'ppviewer.cab' PowerPointViewer.exe \
    && cabextract --lowercase -F '*.ttc' --directory=/usr/share/fonts/msttcore ppviewer.cab \
    && rm -f PowerPointViewer.exe ppviewer.cab

RUN printf '%s\n' \
    "#Normal logging at INFO level" \
    "log4j.rootCategory=INFO, A1" \
    "" \
    "#Detailed logging at DEBUG level" \
    "#log4j.rootCategory=DEBUG, A1" \
    "" \
    "log4j.appender.A1=org.apache.log4j.ConsoleAppender" \
    "log4j.appender.A1.layout=org.apache.log4j.PatternLayout" \
    "log4j.appender.A1.layout.ConversionPattern=%d{DATE} [%t] %-5p %c{1} - %m%n" \
    > /home/docmosis/log4j.properties

USER docmosis
RUN mkdir /home/docmosis/templates /home/docmosis/workingarea

# Tornado configuration
ENV DOCMOSIS_OFFICEDIR=/opt/libreoffice \
    DOCMOSIS_TEMPLATESDIR=templates \
    DOCMOSIS_WORKINGDIR=workingarea \
    DOCMOSIS_LOG4J_CONFIG_FILE=log4j.properties

EXPOSE 8080
VOLUME /home/docmosis/templates
CMD java -Ddocmosis.tornado.render.useUrl=http://localhost:8080/ -jar docmosisTornado.war
