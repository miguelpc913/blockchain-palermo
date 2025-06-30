-include .env

CONTRACT_ADDRESS := 0xYourCCNFTAddressHere
PRIVATE_KEY := e0982b827c2024574f0aa926727d51e10e650a92847ea5809ef56b693546500a
RPC_URL := https://eth-sepolia.g.alchemy.com/v2/dXDWuUbb6olx_QGA5yEr8WtkeXG2VfBb
ETHERSCAN_API_KEY := RBTZ8YNJ7EQ8UDVPP1G8F5SQD7TNH6SUW3

NETWORK_ARGS := --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
NETWORK_ARGS_VERIFY := $(NETWORK_ARGS) --verify -vvvv --etherscan-api-key $(ETHERSCAN_API_KEY)

# Deploy both contracts and verify on Etherscan
deployAndVerify:
	@forge script scripts/Deploy.sol $(NETWORK_ARGS_VERIFY)

# Deploy without verifying
deploy:
	@forge script scripts/Deploy.sol $(NETWORK_ARGS)

# Run a buy interaction
buyNFT:
	@forge script scripts/Interactions.s.sol:BuyNFT $(NETWORK_ARGS)

# Put a token on sale
putOnSale:
	@forge script scripts/Interactions.s.sol:PutOnSaleNFT $(NETWORK_ARGS)

# Call claim logic
claimNFT:
	@forge script scripts/Interactions.s.sol:ClaimNFT $(NETWORK_ARGS)

# Low-level mint using cast (example)
mintCast:
	@forge send $(CONTRACT_ADDRESS) "mintNft()" $(NETWORK_ARGS)
