#!/bin/sh
set -e
# Project Dir

fn_prepare(){
  setfacl -dR -m u:"www-data":rwX -m u:www-data:rwX "/var/www"
  setfacl -R -m u:"www-data":rwX -m u:www-data:rwX "/var/www"
  chown -R www-data:www-data "/var/www"
  # Data
  chmod -R 775 "/var/www/moodle/moodledata"
  chown -R www-data:www-data "/var/www/moodle/moodledata"
}
case $1 in
  prepare)
    fn_prepare
    exit 0
  ;;
  daemon)
    if [ ! -d "/var/www/moodle/moodledata" ]; then
      echo ""
      echo "Executing runtime moodle installer"
      mkdir -p /var/www
      cp -Rf /usr/src/moodle /var/www/
      fn_prepare
      echo ""
      echo "Moodle installed!"
    fi
    /etc/init.d/ntp start
    /etc/init.d/apache2 start
    tail -f /var/log/lastlog
    exit 0;
  ;;
  *)
    param="";
    for p in "$@" ; do
      param="$param \"$p\""
    done
    sh -c "php ${param}"
  ;;
esac