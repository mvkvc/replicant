# Integrity

Due to the fact we are building a permisionless platform there needs to be ways to verify the honesty of participants. There is an incentive to spoof a larger model or not even run any model and mock the local API to only return text. This document will keep track of all the possible approaches we are considering to detect and punish low-trust behavior. One additional constraint is that we want to avoid slashing credits directly as a platform in cases not related to correctness (ex. timeouts).

## Rate limits

Various aspects of the platform will be rate limited. Currently all users have a fixed rate limit on the API that can be individually adjusted. There is also a rate limit on worker connections to combat DDOS attacks. If a user wants to use the network for their business or similar and have a lot of credits, there needs to be a mechanism to increase their rate limit. One other way is to have a base high rate limit for every user but have requests that dont complete also cost credits. Therefore if someone is spamming the network above it's capacity their balance will eventually be exhausted.

## Timeouts

If a worker times out after being assigned a request, meaning either taking too long to return the whole message or returning the message that the stream is complete we will disconnect the worker. Additionally there can be an increasing backoff period for cases where workers continue to not perform adequately.

## Building reputation

There needs to be some financial investment either directly, pay $1 to activate, or indirectly, serve some amount of requests successfully to activate. By increasing the cost of creating new accounts we can combat the spoofing problem. One approach is to have a low-priority queue (thanks Dota 2) where the system works the same but serves a different endpoint that is free to use with rate limits. In order to participate in the main service that costs credits you need to accumulate a certain number of credits in this pool, represented as earning some threshold balance.

## Correctness

In cases of ensuring the correctness of responses we can slash the credits workers service invalid requests and make them have to earn the initial balance again. Some percentage of all requests made on the platform will be rerun on our infrastructure. Ollama supports a random seed paramter so requests made at any temperature can be made deterministic. If the result does not match what the worker provided we will delete the credits of the worker.
