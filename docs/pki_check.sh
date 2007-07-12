#!/bin/sh
#
# This shell script checks the TLS certificates and options needed
# for the secure client/server support of libvirt as documented at
# http://libvirt.org/remote.html#Remote_certificates
#
# Daniel Veillard <veillard@redhat.com>
#
USER=`who am i | awk '{ print $1 }'`
SERVER=1
CLIENT=1
PORT=16514
#
# First get certtool
#
CERTOOL=`which certtool 2>/dev/null`
if [ ! -x $CERTOOL ]
then
    echo Could not locate the certtool program
    echo make sure the gnutls-utils package is installed
    exit 1
fi
echo Found $CERTOOL

#
# Check the directory structure
#
PKI="/etc/pki"
if [ ! -d $PKI ]
then
    echo the $PKI directory is missing, it is usually
    echo installed as part of the filesystem or openssl packages
    exit 1
fi

if [ ! -r $PKI ]
then
    echo the $PKI directory is not readable by $USER
    echo "as root do: chmod a+rx $PKI"
    exit 1
fi
if [ ! -x $PKI ]
then
    echo the $PKI directory is not listable by $USER
    echo "as root do: chmod a+rx $PKI"
    exit 1
fi

CA="$PKI/CA"
if [ ! -d $CA ]
then
    echo the $CA directory is missing, it is usually
    echo installed as part of the or openssl package
    exit 1
fi

if [ ! -r $CA ]
then
    echo the $CA directory is not readable by $USER
    echo "as root do: chmod a+rx $CA"
    exit 1
fi
if [ ! -x $CA ]
then
    echo the $CA directory is not listable by $USER
    echo "as root do: chmod a+rx $CA"
    exit 1
fi

LIBVIRT="$PKI/libvirt"
if [ ! -d $LIBVIRT ]
then
    echo the $LIBVIRT directory is missing, it is usually
    echo installed by the libvirt package
    echo "as root do: mkdir -m 755 $LIBVIRT ; chown root:root $LIBVIRT"
    exit 1
fi

if [ ! -r $LIBVIRT ]
then
    echo the $LIBVIRT directory is not readable by $USER
    echo "as root do: chown root:root $LIBVIRT ; chmod 755 $LIBVIRT"
    exit 1
fi
if [ ! -x $LIBVIRT ]
then
    echo the $LIBVIRT directory is not listable by $USER
    echo "as root do: chown root:root $LIBVIRT ; chmod 755 $LIBVIRT"
    exit 1
fi

LIBVIRTP="$LIBVIRT/private"
if [ ! -d $LIBVIRTP ]
then
    echo the $LIBVIRTP directory is missing, it is usually
    echo installed by the libvirt package
    echo "as root do: mkdir -m 755 $LIBVIRTP ; chown root:root $LIBVIRTP"
    exit 1
fi

if [ ! -r $LIBVIRTP ]
then
    echo the $LIBVIRTP directory is not readable by $USER
    echo "as root do: chown root:root $LIBVIRTP ; chmod 755 $LIBVIRTP"
    exit 1
fi
if [ ! -x $LIBVIRTP ]
then
    echo the $LIBVIRTP directory is not listable by $USER
    echo "as root do: chown root:root $LIBVIRTP ; chmod 755 $LIBVIRTP"
    exit 1
fi

#
# Now check the certificates
# First the CA certificate
#
if [ ! -f $CA/cacert.pem ]
then
    echo the CA certificate $CA/cacert.pem is missing while it
    echo should be installed on both client and servers
    echo "see http://libvirt.org/remote.html#Remote_TLS_CA"
    echo on how to install it
    exit 1
fi
if [ ! -r $CA/cacert.pem ]
then
    echo the CA certificate $CA/cacert.pem is not readable by $USER
    echo "as root do: chmod 644 $CA/cacert.pem"
    exit 1
fi
ORG=`$CERTOOL -i --infile $CA/cacert.pem | grep Issuer | sed 's+Issuer: CN=++'`
if [ "$ORG" == "" ]
then
    echo the CA certificate $CA/cacert.pem does not define the organization
    echo it should probably regenerated
    echo "see http://libvirt.org/remote.html#Remote_TLS_CA"
    echo on how to regenerate it
    exit 1
fi
echo Found CA certificate $CA/cacert.pem for $ORG

# Second the client certificates

if [ -f $LIBVIRT/clientcert.pem ]
then
    if [ ! -r $LIBVIRT/clientcert.pem ]
    then
        echo Client certificate $LIBVIRT/clientcert.pem should be world readable
	echo "as root do: chown root:root $LIBVIRT/clientcert.pem ; chmod 644 $LIBVIRT/clientcert.pem"
    else
        S_ORG=`$CERTOOL -i --infile $LIBVIRT/clientcert.pem | grep Subject: | sed 's+.*O=\([a-zA-Z \._-]*\).*+\1+'`
	if [ "$ORG" != "$S_ORG" ]
	then
	    echo The CA certificate and the client certificate do not match
	    echo CA organization: $ORG
	    echo Client organization: $S_ORG
	fi
	CLIENT=`$CERTOOL -i --infile $LIBVIRT/clientcert.pem | grep Subject: | sed 's+.*CN=\(.[a-zA-Z \._-]*\).*+\1+'`
	echo Found client certificate $LIBVIRT/clientcert.pem for $CLIENT
	if [ ! -e $LIBVIRTP/clientkey.pem ]
	then
	    echo Missing client private key $LIBVIRTP/clientkey.pem
	else
	    echo Found client private key $LIBVIRTP/clientkey.pem
	    OWN=`ls -l $LIBVIRTP/clientkey.pem | awk '{ print $3 }'`
	    MOD=`ls -l $LIBVIRTP/clientkey.pem | awk '{ print $1 }'`
	    if [ "$OWN" != "root" ]
	    then
	        echo The client private key should be owned by root
		echo "as root do: chown root $LIBVIRTP/clientkey.pem"
	    fi
	    if [ "$MOD" != "-rw-r--r--" ]
	    then
	        echo The client private key need to be read by client tools
		echo "as root do: chmod 644 $LIBVIRTP/clientkey.pem"
	    fi
	fi

    fi
else
    echo Did not found $LIBVIRT/clientcert.pem client certificate
    echo The machine cannot act as a client
    echo "see http://libvirt.org/remote.html#Remote_TLS_client_certificates"
    echo on how to regenerate it
    CLIENT=0
fi

# Third the server certificates

if [ -f $LIBVIRT/servercert.pem ]
then
    if [ ! -r $LIBVIRT/servercert.pem ]
    then
        echo Server certificate $LIBVIRT/servercert.pem should be world readable
	echo "as root do: chown root:root $LIBVIRT/servercert.pem ; chmod 644 $LIBVIRT/servercert.pem"
    else
        S_ORG=`$CERTOOL -i --infile $LIBVIRT/servercert.pem | grep Subject: | sed 's+.*O=\([a-zA-Z\. _-]*\).*+\1+'`
	if [ "$ORG" != "$S_ORG" ]
	then
	    echo The CA certificate and the server certificate do not match
	    echo CA organization: $ORG
	    echo Server organization: $S_ORG
	fi
	S_HOST=`$CERTOOL -i --infile $LIBVIRT/servercert.pem | grep Subject: | sed 's+.*CN=\([a-zA-Z\. _-]*\)+\1+'`
	if [ "$S_HOST" != "`hostname -s`" -a "$S_HOST" != "`hostname`" ]
	then
	    echo The server certificate does not seem to match the host name
	    echo hostname: '"'`hostname`'"'
	    echo Server certificate CN: '"'$S_HOST'"'
	fi
	echo Found server certificate $LIBVIRT/servercert.pem for $S_HOST
	if [ ! -e $LIBVIRTP/serverkey.pem ]
	then
	    echo Missing server private key $LIBVIRTP/serverkey.pem
	else
	    echo Found server private key $LIBVIRTP/serverkey.pem
	    OWN=`ls -l $LIBVIRTP/serverkey.pem | awk '{ print $3 }'`
	    MOD=`ls -l $LIBVIRTP/serverkey.pem | awk '{ print $1 }'`
	    if [ "$OWN" != "root" ]
	    then
	        echo The server private key should be owned by root
		echo "as root do: chown root $LIBVIRTP/serverkey.pem"
	    fi
	    if [ "$MOD" != "-rw-------" ]
	    then
	        echo The server private key need to be read only by root
		echo "as root do: chmod 600 $LIBVIRTP/serverkey.pem"
	    fi
	fi

    fi
else
    echo Did not found $LIBVIRT/servercert.pem server certificate
    echo The machine cannot act as a server
    echo "see http://libvirt.org/remote.html#Remote_TLS_server_certificates"
    echo on how to regenerate it
    SERVER=0
fi

if [ "$SERVER" = "1" ]
then
    if [ -r /etc/sysconfig/libvirtd ]
    then
        if [ "`grep '^LIBVIRTD_ARGS' /etc/sysconfig/libvirtd | grep -- '--listen'`" = "" ]
	then
	    echo Make sure /etc/sysconfig/libvirtd is setup to listen to
	    echo TCP/IP connections and restart the libvirtd service
	fi
    fi
    if [ -r /etc/sysconfig/iptables ]
    then
        if [ "`grep $PORT /etc/sysconfig/iptables`" = "" ]
	then
	    echo Make sure /etc/sysconfig/iptables is setup to allow
	    echo incoming TCP/IP connections on port $PORT and
	    echo restart the iptables service
	fi
    fi
fi
