# NFT Marketplace Contract (Foundry)

A minimal **ERC-721 marketplace** smart contract built with **Foundry**.

- **Core actions**: list an NFT, buy a listed NFT, cancel a listing, update listing price
- **Safety**: uses OpenZeppelin `ReentrancyGuard` for `listNft`, `buyNft`, and `cancelListing`
- **Tests**: comprehensive unit tests covering happy paths + revert reasons

<details>
<summary><strong>Quick links</strong> (click to expand)</summary>

- [Quickstart](#quickstart)
- [Repo layout](#repo-layout)
- [Contract overview](#contract-overview)
- [Marketplace flow diagram](#marketplace-flow-diagram)
- [Contract API](#contract-api)
- [Events](#events)
- [Reverts (require messages)](#reverts-require-messages)
- [Run tests](#run-tests)
- [Deploy](#deploy)
- [Interact with the contract (Cast)](#interact-with-the-contract-cast)
- [CI](#ci)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)

</details>

---

## Quickstart

### Prerequisites

- **Git** (submodules are used)
- **Foundry** (`forge`, `cast`, `anvil`)

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Install / setup

```bash
git submodule update --init --recursive
forge --version
```

### Build

```bash
forge build
```

---

## Repo layout

```text
.
├── src/
│   └── NFTMarketplace.sol        # main marketplace contract
├── script/
│   └── NFTMarketplace.s.sol      # DeployScript (reads PRIVATE_KEY env var)
├── test/
│   ├── NFTMarketplace.t.sol      # unit tests
│   └── mocks/
│       └── MockNFT.sol           # simple ERC721 used in tests
├── broadcast/                    # forge script outputs (deploy receipts, addresses)
├── foundry.toml                  # Foundry configuration + remappings
└── .github/workflows/test.yml    # CI: fmt, build, test
```

---

## Contract overview

### What this marketplace stores

The marketplace keeps:

- **A monotonically increasing listing counter**: `_listingIdCounter`
- **A `listings` mapping**: `listingId -> Listing`
- **A `activeListingByNFT` mapping**: `nftContract -> tokenId -> listingIdPlusOne`

That last mapping is a small “index” to prevent double-listing the same NFT:

- It stores **`listingId + 1`** instead of `listingId`
- `0` means **“no active listing known”**
- When a listing becomes inactive, the entry is deleted

### Listing struct

Each `Listing` contains:

- **seller**: address that listed the NFT
- **nftContract**: ERC-721 contract address
- **tokenId**: token id
- **price**: in wei
- **active**: true while it can be bought/cancelled/updated

---

## Marketplace flow diagram

```mermaid
sequenceDiagram
  autonumber
  actor Seller
  actor Buyer
  participant NFT as ERC721 Contract
  participant M as NFTMarketplace

  Seller->>NFT: approve(M, tokenId) OR setApprovalForAll(M, true)
  Seller->>M: listNft(nftContract, tokenId, price)
  M-->>Seller: emits NFTListed(listingId,...)

  Buyer->>M: buyNft(listingId) + msg.value == price
  M->>NFT: safeTransferFrom(Seller, Buyer, tokenId)
  M->>Seller: transfer ETH (call)
  M-->>Buyer: emits NFTSold(listingId,...)

  Note over Seller,M: Seller can cancel while active
  Seller->>M: cancelListing(listingId)
  M-->>Seller: emits ListingCancelled(listingId, seller)
```

---

## Contract API

<details>
<summary><strong>Read this if you’re integrating from a frontend</strong> (click to expand)</summary>

### `listNft(address nftContract, uint256 tokenId, uint256 price) -> uint256 listingId`

- **Who can call**: only the current ERC-721 owner of `tokenId`
- **Requires**:
  - `price > 0`
  - `nftContract != address(0)`
  - `IERC721(nftContract).ownerOf(tokenId) == msg.sender`
  - marketplace is approved (`isApprovedForAll` OR `getApproved(tokenId)`)
  - the NFT is not already actively listed
- **State changes**:
  - creates `Listing` at `listings[listingId]`
  - sets `activeListingByNFT[nftContract][tokenId] = listingId + 1`
- **Emits**: `NFTListed(listingId, seller, nftContract, tokenId, price)`

### `buyNft(uint256 listingId)` (payable)

- **Who can call**: anyone except the seller
- **Requires**:
  - listing is active
  - `msg.value == listing.price`
  - `msg.sender != listing.seller`
- **State changes**:
  - marks listing inactive
  - deletes `activeListingByNFT[nftContract][tokenId]`
- **Transfers**:
  - NFT: `safeTransferFrom(seller, buyer, tokenId)`
  - ETH: forwards `msg.value` to seller with `.call{value: msg.value}("")`
- **Emits**: `NFTSold(listingId, buyer, seller, price)`

### `cancelListing(uint256 listingId)`

- **Who can call**: only the seller
- **Requires**:
  - listing is active
  - `msg.sender == listing.seller`
- **State changes**:
  - marks listing inactive
  - deletes `activeListingByNFT[nftContract][tokenId]`
- **Emits**: `ListingCancelled(listingId, seller)`

### `updateListingPrice(uint256 listingId, uint256 newPrice)`

- **Who can call**: only the seller
- **Requires**:
  - listing is active
  - `msg.sender == listing.seller`
  - `newPrice > 0`
- **State changes**:
  - updates `listing.price`
- **Emits**: `ListingPriceUpdated(listingId, newPrice)`

### Read-only helpers

- `getListing(uint256 listingId) -> (seller, nftContract, tokenId, price, active)`
- `getTotalListings() -> uint256`
- Public mappings:
  - `listings(listingId) -> Listing`
  - `activeListingByNFT(nftContract, tokenId) -> listingIdPlusOne`

</details>

---

## Events

- **`NFTListed(uint256 listingId, address seller, address nftContract, uint256 tokenId, uint256 price)`**
- **`NFTSold(uint256 listingId, address buyer, address seller, uint256 price)`**
- **`ListingCancelled(uint256 listingId, address seller)`**
- **`ListingPriceUpdated(uint256 listingId, uint256 newPrice)`**

---

## Reverts (require messages)

These are the exact revert strings used by `NFTMarketplace.sol`:

- **Listing**
  - `Price must be greater than 0`
  - `Invalid NFT contract`
  - `Not the NFT Owner`
  - `Marketplace not approved`
  - `NFT already listed`
- **Buying**
  - `Listing not active`
  - `Incorrect Price`
  - `Cannot buy your own NFT`
  - `Payment transfer failed`
- **Cancel / update price**
  - `Listing not active`
  - `Not the seller`
  - `Price must be greater than 0`

---

## Run tests

### Unit tests

```bash
forge test -vvv
```

### What’s covered

The suite in `test/NFTMarketplace.t.sol` covers:

- **Listing**: success, event emission, and all revert paths
- **Buying**: success, event emission, wrong price, inactive listing, buying own listing
- **Relisting**: allowed after purchase and after cancel
- **Cancel**: success, event emission, not-seller revert, already-inactive revert
- **Update price**: success, event emission, not-seller revert, inactive revert, zero-price revert

---

## Deploy

### Local deploy (Anvil)

Terminal A:

```bash
anvil
```

Terminal B (use any Anvil private key):

```bash
export PRIVATE_KEY="0xYOUR_ANVIL_PRIVATE_KEY"
forge script script/NFTMarketplace.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --broadcast -vvv
```

### Testnet deploy (Sepolia)

This repo already contains a **previous Sepolia deploy** recorded by Foundry:

- **Network**: Sepolia (chain id `11155111`)
- **Contract**: `NFTMarketplace`
- **Address (from `broadcast/.../run-latest.json`)**: `0x14098c94258118087820b477bd2b9a38e3ce5371`

To deploy again:

```bash
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_KEY"
export PRIVATE_KEY="0xYOUR_PRIVATE_KEY"

forge script script/NFTMarketplace.s.sol:DeployScript --rpc-url "$SEPOLIA_RPC_URL" --broadcast -vvv
```

> Note: `DeployScript` reads `PRIVATE_KEY` via `vm.envUint("PRIVATE_KEY")`, so you must export it (or load it via your shell/environment).

---

## Interact with the contract (Cast)

<details>
<summary><strong>Step-by-step example (approve → list → buy)</strong> (click to expand)</summary>

You’ll need:

- an **ERC-721 contract address** (`NFT_CONTRACT`)
- a **token id** (`TOKEN_ID`) owned by the seller
- the **marketplace address** (`MARKETPLACE`)
- an RPC URL

### 1) Approve the marketplace (seller)

Approve a single token:

```bash
cast send "$NFT_CONTRACT" "approve(address,uint256)" "$MARKETPLACE" "$TOKEN_ID" \
  --rpc-url "$RPC_URL" --private-key "$SELLER_PRIVATE_KEY"
```

Or approve all tokens:

```bash
cast send "$NFT_CONTRACT" "setApprovalForAll(address,bool)" "$MARKETPLACE" true \
  --rpc-url "$RPC_URL" --private-key "$SELLER_PRIVATE_KEY"
```

### 2) List the NFT (seller)

```bash
cast send "$MARKETPLACE" "listNft(address,uint256,uint256)(uint256)" "$NFT_CONTRACT" "$TOKEN_ID" "$PRICE_WEI" \
  --rpc-url "$RPC_URL" --private-key "$SELLER_PRIVATE_KEY"
```

### 3) Buy the NFT (buyer)

```bash
cast send "$MARKETPLACE" "buyNft(uint256)" "$LISTING_ID" \
  --value "$PRICE_WEI" --rpc-url "$RPC_URL" --private-key "$BUYER_PRIVATE_KEY"
```

</details>

---

## CI

GitHub Actions workflow `test.yml` runs on push/PR:

- `forge fmt --check`
- `forge build --sizes`
- `forge test -vvv`

---

## Troubleshooting

<details>
<summary><strong>“Marketplace not approved” when listing</strong></summary>

The marketplace requires either:

- `getApproved(tokenId) == marketplace`, or
- `isApprovedForAll(owner, marketplace) == true`

Approve first using `approve` or `setApprovalForAll`.

</details>

<details>
<summary><strong>“Listing not active” when buying / cancelling / updating</strong></summary>

Listings become inactive after:

- a successful `buyNft`, or
- a successful `cancelListing`

Re-list the NFT to create a new active listing.

</details>

<details>
<summary><strong>Buying fails with safeTransferFrom</strong></summary>

`buyNft` calls `safeTransferFrom(seller, buyer, tokenId)`.

- If the buyer is a contract, it must implement ERC-721 receiver (`onERC721Received`) or the transfer will revert.

</details>

---

## Security notes

This is a learning/demo marketplace and is **not audited**.

Important considerations:

- **Funds forwarding**: ETH is forwarded to the seller via `.call`. If it fails, the buy reverts (`Payment transfer failed`).
- **Approval dependency**: listing requires marketplace approval, but the seller could revoke approval after listing; then `buyNft` may revert at transfer time.
- **No fees / no escrow**: the contract does not escrow NFTs or charge marketplace fees.
- **No listing expiration**: listings stay active until bought/cancelled.

---

## Foundry reference

- Foundry book: `https://book.getfoundry.sh/`
