

curl -X POST https://rpc.node2.canopy.eu.nodefleet.net/v1/query/block-by-height -H "Content-Type: application/json" -d '{"height":1}'
curl -X POST https://rpc.node1.canopy.eu.nodefleet.net/v1/query/block-by-height -H "Content-Type: application/json" -d '{"height":1}'

curl -X POST https://rpc.node2.canopy.us.nodefleet.net/v1/query/block-by-height -H "Content-Type: application/json" -d '{"height":1}'
curl -X POST https://rpc.node1.canopy.us.nodefleet.net/v1/query/block-by-height -H "Content-Type: application/json" -d '{"height":1}'
