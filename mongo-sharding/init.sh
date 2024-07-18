#!/bin/bash

echo "Building and launching services..."
docker compose up -d

echo "Waiting for MongoDB to start..."
sleep 10

echo "Initializing the configuration server..."
docker exec -i configSrv mongosh --port 27017 --quiet --eval '
rs.initiate(
  {
    _id: "config_server",
    configsvr: true,
    members: [
      { _id: 0, host: "configSrv:27017" }
    ]
  }
)
'

echo "Initialization of 1 shard..."
docker exec -i shard1 mongosh --port 27018 --quiet --eval '
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" },
       // { _id : 1, host : "shard2:27019" }
      ]
    }
)
'

echo "Initialization of 2 shard..."
docker exec -i shard2 mongosh --port 27019 --quiet --eval '
rs.initiate(
    {
      _id : "shard2",
      members: [
       // { _id : 0, host : "shard1:27018" },
        { _id : 1, host : "shard2:27019" }
      ]
    }
)
'

echo "Waiting for shards to initialize..."
sleep 5

echo "Initializing the router..."
docker exec -i mongos_router mongosh --port 27020 --quiet --eval '
sh.addShard( "shard1/shard1:27018");
sh.addShard( "shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
for(var i = 0; i < 1000; i++) {
  db.getSiblingDB("somedb").helloDoc.insert({age:i, name:"ly"+i});
}
'

echo "Initialization complete."
