
sudo ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f nciou.ldif

sudo ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f group_nciuser.ldif

slappasswd

sudo ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f user_nciuser1.ldif