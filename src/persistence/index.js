if (process.env.CONNECTION_MYSQLDB_PROPERTIES || process.env.MYSQL_HOST) module.exports = require('./mysql');
else module.exports = require('./sqlite');
