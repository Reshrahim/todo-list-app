extension radius

param environment string

@description('Administrator password for the MySQL database, also supplied to the application as MYSQL_PASSWORD.')
@secure()
param mysqlPassword string

@description('Password/token for the OCI registry the containerImages recipe pushes to (a GitHub token with write:packages for ghcr.io).')
@secure()
param registryPassword string

@description('Username for the OCI registry the containerImages recipe pushes to (the GitHub actor for ghcr.io).')
@secure()
param registryUsername string

resource todoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'todo-list-app'
  properties: {
    environment: environment
  }
}

resource mysqlDb 'Radius.Data/mySqlDatabases@2025-08-01-preview' = {
  name: 'mysql'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'src/persistence/mysql.js#L31'
    database: 'todos'
    password: mysqlPassword
    username: 'myadmin'
    version: '8.0'
  }
}

resource mysqlSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'mysql-client-credentials'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'src/persistence/mysql.js#L14'
    data: {
      password: {
        value: mysqlPassword
      }
    }
  }
}

// Do not change this Secret's name value from 'radius-ghcr-registry-creds'.
// The containerImages recipe looks up registry credentials by that fixed name.
resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: '.radius/app.bicep#L53'
    data: {
      password: {
        value: registryPassword
      }
      username: {
        value: registryUsername
      }
    }
  }
}

resource todoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'todo-list-app-image'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'Dockerfile'
    tag: '5a6fbf5'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/Reshrahim/todo-list-app.git?ref=5a6fbf5caf982f1d928fe6c1c32aa74f1e95e063'
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource todoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'todo-list-app'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'src/index.js#L18'
    containers: {
      todo: {
        image: todoImage.properties.imageReference
        env: {
          MYSQL_DB: {
            value: 'todos'
          }
          MYSQL_HOST: {
            value: mysqlDb.properties.host
          }
          MYSQL_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: mysqlSecret.name
                key: 'password'
              }
            }
          }
          MYSQL_USER: {
            value: 'myadmin'
          }
        }
        ports: {
          web: {
            containerPort: 3000
          }
        }
      }
    }
  }
}
