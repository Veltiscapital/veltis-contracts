# Veltis Platform

Veltis is a Web3 platform that enables users to create, fractionalize, list, and trade IP NFTs (Intellectual Property Non-Fungible Tokens) in a decentralized marketplace. The platform combines user-friendly interfaces with blockchain technology to provide a seamless experience for creators and collectors.

## Project Status

This project is currently in active development.

## Features

### Current Implementation
- **User Authentication**: Create accounts, log in, and log out securely with Clerk
- **Wallet Connection**: Connect various blockchain wallets to interact with the platform
- **Responsive Design**: Beautiful user interface optimized for different devices
- **Mint IP-NFTs**: Create IP-NFTs with document uploads
- **Fractionalize IP-NFTs**: Divide ownership of valuable NFTs into tradable fractions
- **Browse and manage your IP-NFTs**: View and manage your NFT portfolio

### Upcoming Features
- **Enhanced Marketplace**: Buy and sell fractionalized NFTs with transparent pricing
- **Advanced Portfolio Management**: Track your NFT investments and transactions
- **Analytics Dashboard**: Insights into your NFT performance

## Tech Stack

- **Frontend**: React with TypeScript
- **Build Tool**: Vite for fast development and optimized builds
- **Styling**: Tailwind CSS
- **Authentication**: Clerk
- **Blockchain Integration**: Ethers.js
- **Storage**: NFT.storage for IPFS storage
- **NFT Data**: Alchemy SDK
- **Deployment**: Vercel

## Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- MetaMask or other Web3 wallet

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/rodrigomacias/veltis.git
   cd veltis
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env.local` file with the required environment variables:
   ```
   VITE_CLERK_PUBLISHABLE_KEY=your_clerk_key
   VITE_NFT_STORAGE_API_KEY=your_nft_storage_key
   VITE_BLOCKCHAIN_NETWORK=polygon-amoy
   VITE_IP_NFT_REGISTRY_CONTRACT=0x0C0cE3CA0d5d21E2f58a7505Afc7856a36fd1363
   VITE_SIMPLE_IP_NFT_REGISTRY_CONTRACT=0x0C0cE3CA0d5d21E2f58a7505Afc7856a36fd1363
   VITE_POLYGON_AMOY_RPC_URL=https://rpc-amoy.polygon.technology
   VITE_POLYGON_MAINNET_RPC_URL=https://polygon-rpc.com
   VITE_CHAIN_ID=80001
   VITE_NETWORK_NAME=Polygon Mumbai
   ```

4. Start the development server:
   ```bash
   npm run dev
   ```

## Project Structure

```
veltis/
├── public/             # Static assets
├── src/                # Source code
│   ├── components/     # Reusable UI components
│   ├── contexts/       # React context providers
│   ├── hooks/          # Custom React hooks
│   ├── pages/          # Application pages
│   ├── services/       # API and service integrations
│   ├── types/          # TypeScript type definitions
│   ├── utils/          # Utility functions
│   ├── App.tsx         # Main application component
│   └── main.tsx        # Application entry point
├── .env.example        # Example environment variables
├── .gitignore          # Git ignore file
├── index.html          # HTML entry point
├── package.json        # Project dependencies
├── tsconfig.json       # TypeScript configuration
├── vite.config.ts      # Vite configuration
└── README.md           # Project documentation
```

## Deployment

### Prerequisites

- Vercel account
- Environment variables configured in Vercel

### Deployment Steps

1. Create a `.env.production` file with the required environment variables (similar to `.env.local` but with production values).

2. Use the deployment script:
   ```bash
   ./deploy.sh
   ```

   This script will:
   - Check for required environment variables
   - Install dependencies
   - Build the application
   - Deploy to Vercel

3. Alternatively, you can deploy manually:
   ```bash
   # Build the application
   npm run build
   
   # Deploy to Vercel
   vercel --prod
   ```

### Environment Variables in Vercel

Make sure to add all required environment variables in your Vercel project settings:

1. Go to your Vercel dashboard
2. Select your project
3. Go to "Settings" → "Environment Variables"
4. Add all the environment variables from your `.env.production` file

## Troubleshooting

### Blank Page on Deployment

If you see a blank page after deployment, check the following:

1. **Environment Variables**: Ensure all required environment variables are set in Vercel.
2. **Browser Console**: Check for errors in the browser console.
3. **Vercel Logs**: Check the deployment logs in Vercel for any build or runtime errors.
4. **CORS Issues**: If you're using an API, ensure CORS is properly configured.

### API Connection Issues

The application includes a fallback mechanism that uses mock data when the API is unavailable. If you see a message about using mock data:

1. Check if your API is running and accessible
2. Verify the API URL in your environment variables
3. Check network connectivity

## Usage Guide

### User Authentication

1. Visit the homepage and click "Sign Up" to create a new account
2. Verify your email address through the link sent to your email
3. Log in with your credentials to access the platform features

### Connecting Your Wallet

1. Click on the "Connect Wallet" button in the header
2. Select your preferred wallet provider (MetaMask, WalletConnect, etc.)
3. Follow the prompts to connect your wallet
4. Once connected, your wallet address will be displayed in the header

### Minting an NFT

1. Navigate to the "Create" section
2. Upload your content and fill in the metadata
3. Set royalty percentages and other properties
4. Sign the transaction with your connected wallet
5. Wait for the transaction to be confirmed on the blockchain

### Fractionalizing an NFT

1. Go to "My NFTs" and select the NFT you want to fractionalize
2. Click "Fractionalize" and set the number of fractions
3. Configure additional parameters (fraction name, symbol, etc.)
4. Sign the transaction with your connected wallet
5. Once confirmed, your fractions will be available for trading

## License

[MIT License](LICENSE)
