import { ethers } from 'ethers';
import {
  MultiFungibleTokenManager as MultiFungibleTokenManagerContract,
  MultiFungibleTokenManager__factory,
} from '@webb-tools/masp-anchor-contracts';
import { Deployer } from '@webb-tools/create2-utils';

export class MultiFungibleTokenManager {
  contract: MultiFungibleTokenManagerContract;
  signer: ethers.Signer;

  constructor(contract: MultiFungibleTokenManagerContract, signer: ethers.Signer) {
    this.contract = contract;
    this.signer;
  }

  public static async create2MultiFungibleTokenManager(
    deployer: Deployer,
    saltHex: string,
    signer: ethers.Signer
  ) {
    const { contract: manager } = await deployer.deploy(
      MultiFungibleTokenManager__factory,
      saltHex,
      signer
    );

    return new MultiFungibleTokenManager(manager, signer);
  }

  public static async createMultiFungibleTokenManager(deployer: ethers.Signer) {
    const factory = new MultiFungibleTokenManager__factory(deployer);
    const contract = await factory.deploy();

    await contract.deployed();

    const manager = new MultiFungibleTokenManager(contract, deployer);
    return manager;
  }

  public static async connect(managerAddress: string, signer: ethers.Signer) {
    const managerContract = MultiFungibleTokenManager__factory.connect(managerAddress, signer);
    const manager = new MultiFungibleTokenManager(managerContract, signer);
    return manager;
  }

  public async initialize(registry: string, feeRecipient: string) {
    const tx = await this.contract.initialize(registry, feeRecipient, { gasLimit: '0x5B8D80' });

    await tx.wait();
  }

  public async registerToken(
    tokenHandler: string,
    name: string,
    symbol: string,
    saltHex: string,
    limit: string,
    feePercentage: number,
    isNativeAllowed: boolean
  ) {
    const tx = await this.contract.registerToken(
      tokenHandler,
      name,
      symbol,
      saltHex,
      limit,
      feePercentage,
      isNativeAllowed,
      await this.signer.getAddress()
    );
    await tx.wait();
  }

  public async setRegistry(registry: string) {
    const tx = await this.contract.setRegistry(registry);
    await tx.wait();
  }
}
