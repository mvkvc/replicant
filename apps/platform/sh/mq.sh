#! /bin/sh

ENGINE=podman

AMQP_CONTAINER=platform_mq
AMQP_IMAGE=docker.io/rabbitmq:3.12-management
AMQP_PATH=$(pwd)/.mq/data

mkdir -p $AMQP_PATH

$ENGINE run --rm --replace --name $AMQP_CONTAINER \
  -p "$PLATFORM_AMQP_PORT":5672 \
  -p "$PLATFORM_AMQP_MANAGEMENT_PORT":15672 \
  -v $AMQP_PATH:/var/lib/rabbitmq \
  $AMQP_IMAGE
