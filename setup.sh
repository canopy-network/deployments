docker run --user root -it -p 50000:50000 -p 50001:50001 -p 50002:50002 -p 50003:50003 -p 9001:9001 --name canopy-config  --volume ${PWD}/canopy_data/node1/:/root/.canopy/ canopynetwork/canopy && \
docker stop canopy-config && docker rm canopy-config && \
cp canopy_data/node1/validator_key.json canopy_data/node2/ && \
cp canopy_data/node1/keystore.json canopy_data/node2/
