# istio-installer

SWS and Istio install script on OpenShift

  Description: This script

  *

  Usage:

  ./prep_istio.sh
  variable USR running on user's home directory, by default 'hudson' will be taken
  variable REMOVE_ISTIO when set 'true' it will remove Istio from OC
  variable INSTALL_ISTIO when set 'true' it will install Istio on OC
  variable INSTALL_BOOKINFO when set 'true', it will instakk BookInfo application, VALID when INSTALL_ISTIO is set 'true'
  variable REMOVE_SWS when set 'true' it will remove SWS from OC
  variable INSTALL_SWS when set 'true' it will install SWS on OC
  variable ISTIO_VERSION is the version of Istio to be installed, by default latest version will be used
  variable DOCKER_USERNAME username to login into Docker hub
  variable DOCKER_PASSWORD docker password
  variable OS_HOSTNAME Openshift hostname, default 'localhost'
  variable OS_PORT Openshift port, default '8443'
  variable OS_TOKEN Openshift token, will be used token login if given, otherwise credentials will be used
  variable OS_USERNAME Openshift login, default 'admin'
  variable OS_PASSWORD Openshift password, default 'redhat'

