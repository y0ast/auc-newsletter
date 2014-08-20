#Automatic newsletter for AUC and AUCSA

Heroku dependencies: sendgrid, postgres

Intended for use with MailChimp.

Config.yml requires:
- db : [Database url]
- username: [Gmail username]
- password: [Gmail password]


```
brew install postgres
initdb /usr/local/var/postgres
createdb newsletter
```

Url then becomes `db: postgres://localhost/newsletter`

To start and stop postgres:
```
pg_ctl -D /usr/local/var/postgres start
pg_ctl -D /usr/local/var/postgres stop
```
