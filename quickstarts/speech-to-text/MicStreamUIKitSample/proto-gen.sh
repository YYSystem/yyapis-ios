PROTOS_DIR=SampleApp/SampleApp/Protos
protoc $PROTOS_DIR/*.proto \
    --proto_path=$PROTOS_DIR \
    --swift_opt=Visibility=Public \
    --swift_out=$PROTOS_DIR \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=$PROTOS_DIR
