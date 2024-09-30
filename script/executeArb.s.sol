// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IUniswapV3Factory} from "../src/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../src/interfaces/IUniswapV3Pool.sol";
import {ArbOptimiser} from "../src/libraries/ArbOptimiser.sol";
import {FixedPoint96} from "../src/libraries/FixedPoint96.sol";
import {FlashRouteProcessor2} from "../src/FlashRouteProcessor2.sol";

contract executeArb is Script {
    function run() public {
        vm.startBroadcast();

        address wmatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        address dimo = 0xE261D618a959aFfFd53168Cd07D12E37B26761db;
        address usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        address usdc = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        // address bnb = 0x3BA4c387f786bFEE076A58914F5Bd38d668B42c3;
        // address sol = 0xd93f7E271cB87c23AaA73edC008A79646d1F9912;
        // address wbtc = 0x2C89bbc92BD86F8075d1DEcc58C7F4E0107f286b;
        // address shib = 0x6f8a06447Ff6FcF75d803135a7de15CE88C1d4ec;
        // address aave = 0xD6DF932A45C0f255f85145f286eA0b292B21C90B;
        // address grt = 0x5fe2B58c013d7601147DcdD68C143A77499f5531;
        // address ldo = 0xC3C7d422809852031b44ab29EEC9F1EfF2A58756;
        // address frax = 0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89;
        // address sand = 0xBbba073C31bF03b8ACf7c28EF0738DeCF3695683;
        // address mana = 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4;
        // address comp = 0x8505b9d2254A7Ae468c0E9dd10Ccea3A837aef5c;
        // address USDCe = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        // address LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;
        // address WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
        // address UNI = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;
        // address SUSHI = 0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a;
        // address QUICK = 0x831753DD7087CaC61aB5644b308642cc1c33Dc13;
        // address newQUICK = 0xB5C064F955D8e7F38fE0460C556a72987494eE17;
        // address GHST = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;
        // address TEL = 0xdF7837DE1F2Fa4631D716CF2502f8b230F1dcc32;
        // address BAL = 0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3;
        // address EMON = 0xd6A5aB46ead26f49b03bBB1F9EB1Ad5c1767974a;
        // address COMBO = 0x6DdB31002abC64e1479Fc439692F7eA061e78165;
        // address BUSD = 0xdAb529f40E671A1D4bF91361c21bf9f0C9712ab7;
        // address ICE = 0xc6C855AD634dCDAd23e64DA71Ba85b8C51E5aD7c;
        // address stMATIC = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;
        // address TUSD = 0x2e1AD108fF1D8C782fcBbB89AAd783aC49586756;
        // address SX = 0x840195888Db4D6A99ED9F73FcD3B225Bb3cB1A79;
        // address NZDS = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;
        // address CXO = 0xf2ae0038696774d65E67892c9D301C5f2CbbDa58;
        // address agEUR = 0xE0B52e49357Fd4DAf2c15e02058DCE6BC0057db4;
        // address WOO = 0x1B815d120B3eF02039Ee11dC2d33DE7aA4a8C603;
        // address KNC = 0x324b28d6565f784d596422B0F2E5aB6e9CFA1Dc7;
        // address EURS = 0xE111178A87A3BFf0c8d18DECBa5798827539Ae99;
        // address ORBS = 0x614389EaAE0A6821DC49062D56BDA3d9d45Fa2ff;
        // address CEL = 0xD85d1e945766Fea5Eda9103F918Bd915FbCa63E6;
        // address CADC = 0x5d146d8B1dACb1EBBA5cb005ae1059DA8a1FbF57;
        // address FXS = 0x3e121107F6F22DA4911079845a470757aF4e1A1b;
        // address MONA = 0x6968105460f67c3BF751bE7C15f92F5286Fd0CE5;
        // address NEX = 0xA486c6BC102f409180cCB8a94ba045D39f8fc7cB;
        // address PLA = 0x8765f05ADce126d70bcdF1b0a48Db573316662eB;
        // address OM = 0xC3Ec80343D2bae2F8E680FDADDe7C17E71E114ea;
        // address DFYN = 0xC168E40227E4ebD8C1caE80F7a55a4F0e6D66C97;
        // address SWAP = 0x3809dcDd5dDe24B37AbE64A5a339784c3323c44F;
        // address GCR = 0xa69d14d6369E414a32a5C7E729B7afbAfd285965;
        // address GET = 0x43Df9c0a1156c96cEa98737b511ac89D0e2A1F46;
        // address AWX = 0x56A0eFEFC9F1FBb54FBd25629Ac2aA764F1b56F7;
        // address AWG = 0xAEe0ffb690B37449B7f1C49B199E1E3ec6084490;
        // address ADS = 0x598e49f01bEfeB1753737934a5b11fea9119C796;
        // address CGG = 0x2Ab4f9aC80F33071211729e45Cfc346C1f8446d5;
        // address WRLD = 0xD5d86FC8d5C0Ea1aC1Ac5Dfab6E529c9967a45E9;
        // address ROUTE = 0x16ECCfDbb4eE1A85A33f3A9B21175Cd7Ae753dB4;
        // address DODO = 0xe4Bf2864ebeC7B7fDf6Eeca9BaCAe7cDfDAffe78;
        // address CHAIN = 0xd55fCe7CDaB84d84f2EF3F99816D765a2a94a509;
        // address MYST = 0x1379E8886A944d2D9d440b3d88DF536Aea08d9F3;
        // address RNDR = 0xB9638272aD6998708de56BBC0A290a1dE534a578;
        // address JRT = 0x596eBE76e2DB4470966ea395B0d063aC6197A8C5;
        // address MAHA = 0xeDd6cA8A4202d4a36611e2fff109648c4863ae19;
        // address POOL = 0x25788a1a171ec66Da6502f9975a15B609fF54CF6;
        // address COT = 0x111111517e4929D3dcbdfa7CCe55d30d4B6BC4d6;
        // address ANRX = 0xEe9A352F6aAc4aF1A5B9f467F6a93E0ffBe9Dd35;
        // address SDT = 0x361A5a4993493cE00f61C32d4EcCA5512b82CE90;
        // address XCAD = 0xA55870278d6389ec5B524553D03C04F5677c061E;
        // address POP = 0xC5B57e9a1E7914FDA753A88f24E5703e617Ee50c;
        // address DHT = 0x8C92e38eCA8210f4fcBf17F0951b198Dd7668292;
        // address UCO = 0x23D29D30e35C5e8D321e1dc9A8a61BFD846D4C5C;
        // address JPYC = 0x6AE7Dfc73E0dDE2aa99ac063DcF7e8A63265108c;
        // address UBT = 0x7FBc10850caE055B27039aF31bD258430e714c62;
        // address INST = 0xf50D05A1402d0adAfA880D36050736f9f6ee7dee;
        // address xDG = 0xc6480Da81151B2277761024599E8Db2Ad4C388C8;
        // address PBR = 0x0D6ae2a429df13e44A07Cd2969E085e4833f64A0;
        // address BLANK = 0xf4C83080E80AE530d6f8180572cBbf1Ac9D5d435;
        // address RBC = 0xF501dd45a1198C2E1b5aEF5314A68B9006D842E0;
        // address BANK = 0xFC2e967BF55F545d656DE5C40618c1AE80EB6EdF;
        // address NORD = 0xF6F85b3f9fd581C2eE717c404F7684486F057F95;
        // address MOD = 0x8346Ab8d5EA7A9Db0209aEd2d1806AFA0E2c4C21;
        // address AWS = 0xA96D47c621a8316d4F9539E3B38180C7067e84CA;
        // address YfDAI = 0x7E7fF932FAb08A0af569f93Ce65e7b8b23698Ad8;
        // address IMX = 0x183070C90B34A63292cC908Ce1b263Cb56D49A7F;
        // address DATA = 0x3a9A81d576d83FF21f26f325066054540720fC34;
        // address APE = 0xB7b31a6BC18e48888545CE79e83E06003bE70930;
        // address MaticX = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
        // address code = 0x2d04D3F49D11C11Ad99cacA515d209c741c1bd9B;
        // address gbl = 0xC14A7747cFec02CfeA62E72BB93538DE6B2078E6;
        // address nandi = 0xACAC2eB039A3F1A48f2596FAA1990D2d02E66144;
        // address fish = 0x3a3Df212b7AA91Aa0402B9035b098891d276572B;
        // address ala = 0xF5c068f28eBF91b22e52C2ecD230621879e914B8;
        // address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        // address brz = 0x4eD141110F6EeeAbA9A1df36d8c26f684d2475Dc;
        // address brla = 0xE6A537a407488807F0bbeb0038B79004f19DDDFb;
        // address nesg = 0xE64ceD357672e70fA5cE1fCAEc52c8F690528bcC;
        // address gcr = 0xF544112415C1a275AA29aa268F193e5B9d15cc34;
        // address _1INCH = 0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f;
        // address snx = 0x50B728D8D964fd00C2d0AAD81718b71311feF68a;
        // address ggt = 0x8349314651eDe274f8c5FeF01Aa65fF8da75E57c;
        // address gmt = 0x714DB550b574b3E927af3D93E26127D15721D4C2;
        // address DeHu = 0xB0a9C70FBBAF01Fc7B97d15bb7DF1C6c651720b7;
        // address TRUEHNG = 0x1C037A9fcA50668B828905c954CABcbCf89A74D3;
        // address Pepeito = 0x96786eD03954fa85C7a75132BaeaBa8a55a3B885;
        // address SPEPE = 0xfcA466F2fA8E667a517C9C6cfa99Cf985be5d9B1;
        // address algb = 0x0169eC1f8f639B32Eec6D923e24C2A2ff45B9DD6;
        // address Dyl = 0x4A506181f07Da5ddFDA4ca4c2Fa4c67001dB94B4;
        // address KC = 0x784665471bB8B945b57A76a9200B109Ee214E789;
        // address TRUEHN = 0x9d9F8a6A6aD70D5670B7b5Ca2042c7E106E2fB78;
        // address DEXShare = 0x81C737102aac7c092Da1A834DeEdb39a0e56663f;
        // address GETON = 0x1b9D6a5FC2382A97777FC56CEBb109BCa815C3BE;
        // address PolyDoge = 0x8A953CfE442c5E8855cc6c61b1293FA648BAE472;
        // address ELK = 0xeEeEEb57642040bE42185f49C52F7E9B38f8eeeE;
        // address DRAGON2024 = 0xED3D18f841D82604F729464835c739a331F1E49B;
        // address JUGNI = 0xE313bcB77dbA15F39Ff0B9cEABe140cedD0953cB;
        // address ETNA = 0x5eE0fE440a4cA7F41bCF06b20c2A30a404E21069;
        // address PLR = 0xa6b37fC85d870711C56FbcB8afe2f8dB049AE774;
        // address lvc = 0x79774Bf5867ac4e014A48B471CBd94A01cc9a4D2;
        // address knc = 0x1C954E8fe737F99f68Fa1CCda3e51ebDB291948C;
        // address ace = 0x9627a3d6872bE48410fCEce9b1dDD344Bf08c53e;

        // address[] memory tokens = new address[](120);
        address[] memory tokens = new address[](5);
        tokens[0] = wmatic;
        tokens[1] = weth;
        tokens[2] = dimo;
        tokens[3] = usdt;
        tokens[4] = usdc;
        // tokens[5] = bnb;
        // tokens[6] = sol;
        // tokens[7] = wbtc;
        // tokens[8] = shib;
        // tokens[9] = aave;
        // tokens[10] = grt;
        // tokens[11] = ldo;
        // tokens[12] = frax;
        // tokens[13] = sand;
        // tokens[14] = mana;
        // tokens[15] = comp;
        // tokens[16] = USDCe;
        // tokens[17] = LINK;
        // tokens[18] = WBTC;
        // tokens[19] = UNI;
        // tokens[20] = SUSHI;
        // tokens[21] = QUICK;
        // tokens[22] = newQUICK;
        // tokens[23] = GHST;
        // tokens[24] = TEL;
        // tokens[25] = BAL;
        // tokens[26] = EMON;
        // tokens[27] = COMBO;
        // tokens[28] = BUSD;
        // tokens[29] = ICE;
        // tokens[30] = stMATIC;
        // tokens[31] = TUSD;
        // tokens[32] = SX;
        // tokens[33] = NZDS;
        // tokens[34] = CXO;
        // tokens[35] = agEUR;
        // tokens[36] = WOO;
        // tokens[37] = KNC;
        // tokens[38] = EURS;
        // tokens[39] = ORBS;
        // tokens[40] = CEL;
        // tokens[41] = CADC;
        // tokens[42] = FXS;
        // tokens[43] = MONA;
        // tokens[44] = NEX;
        // tokens[45] = PLA;
        // tokens[46] = OM;
        // tokens[47] = DFYN;
        // tokens[48] = SWAP;
        // tokens[49] = GCR;
        // tokens[50] = GET;
        // tokens[51] = AWX;
        // tokens[52] = AWG;
        // tokens[53] = ADS;
        // tokens[54] = CGG;
        // tokens[55] = WRLD;
        // tokens[56] = ROUTE;
        // tokens[57] = DODO;
        // tokens[58] = CHAIN;
        // tokens[59] = MYST;
        // tokens[60] = RNDR;
        // tokens[61] = JRT;
        // tokens[62] = MAHA;
        // tokens[63] = POOL;
        // tokens[64] = COT;
        // tokens[65] = ANRX;
        // tokens[66] = SDT;
        // tokens[67] = XCAD;
        // tokens[68] = POP;
        // tokens[69] = DHT;
        // tokens[70] = UCO;
        // tokens[71] = JPYC;
        // tokens[72] = UBT;
        // tokens[73] = INST;
        // tokens[74] = xDG;
        // tokens[75] = PBR;
        // tokens[76] = BLANK;
        // tokens[77] = RBC;
        // tokens[78] = BANK;
        // tokens[79] = NORD;
        // tokens[80] = MOD;
        // tokens[81] = AWS;
        // tokens[82] = YfDAI;
        // tokens[83] = IMX;
        // tokens[84] = DATA;
        // tokens[85] = APE;
        // tokens[86] = MaticX;
        // tokens[87] = code;
        // tokens[88] = gbl;
        // tokens[89] = nandi;
        // tokens[90] = fish;
        // tokens[91] = ala;
        // tokens[92] = dai;
        // tokens[93] = brz;
        // tokens[94] = brla;
        // tokens[95] = nesg;
        // tokens[96] = gcr;
        // tokens[97] = _1INCH;
        // tokens[98] = snx;
        // tokens[99] = ggt;
        // tokens[100] = gmt;
        // tokens[101] = DeHu;
        // tokens[102] = TRUEHNG;
        // tokens[103] = Pepeito;
        // tokens[104] = SPEPE;
        // tokens[105] = algb;
        // tokens[106] = Dyl;
        // tokens[107] = KC;
        // tokens[108] = TRUEHN;
        // tokens[109] = DEXShare;
        // tokens[110] = GETON;
        // tokens[111] = PolyDoge;
        // tokens[112] = ELK;
        // tokens[113] = DRAGON2024;
        // tokens[114] = JUGNI;
        // tokens[115] = ETNA;
        // tokens[116] = PLR;
        // tokens[117] = lvc;
        // tokens[118] = knc;
        // tokens[119] = ace;

        uint24[] memory fees = new uint24[](3);
        fees[0] = 3e3;
        fees[1] = 5e2;
        fees[2] = 1e4;
        address[] memory priviledged = new address[](0);
        // uint256 gasThreshold = tx.gasprice * 3e5; // rough estimate of 300,000 gas used in a transaction - in practice should be more accurately calculated
        uint256 gasThreshold = 0; // uncomment to find any feasible arbitrage opportinities disregarding gas costs - will not be profitable
        FlashRouteProcessor2 flashRouteProcessor2 = new FlashRouteProcessor2(
            priviledged
        );
        console.log("gasThreshold %i", gasThreshold);
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(
            0x1F98431c8aD98523631AE4a59f267346ea31F984
        ); // Polygon factory address as on https://docs.uniswap.org/contracts/v3/reference/deployments/polygon-deployments
        for (uint8 i = 0; i < tokens.length; ++i) {
            address tokenIn = tokens[i];
            for (uint8 j = 0; j < tokens.length; ++j) {
                if (i == j) continue;
                address tokenOut = tokens[j];
                for (uint8 k = 0; k < fees.length; ++k) {
                    uint24 fee0 = fees[k];
                    if (
                        uniswapV3Factory.getPool(tokenIn, tokenOut, fee0) ==
                        0x0000000000000000000000000000000000000000
                    ) continue;
                    for (uint8 l = 0; l < fees.length; ++l) {
                        if (k == l) continue;
                        uint24 fee1 = fees[l];
                        if (
                            uniswapV3Factory.getPool(tokenIn, tokenOut, fee1) ==
                            0x0000000000000000000000000000000000000000
                        ) continue;
                        bool zeroForOne = tokenIn < tokenOut;
                        (
                            int256 amountCalculatedIn,
                            int256 amountCalculatedOut,
                            bool poolSwapped
                        ) = ArbOptimiser.optimalTwoPointArbInput(
                                tokenIn,
                                tokenOut,
                                fee0,
                                fee1
                            );
                        if (poolSwapped) (fee0, fee1) = (fee1, fee0);
                        uint256 output = uint256(
                            -(amountCalculatedOut + amountCalculatedIn)
                        );
                        if (output > 0) {
                            if (tokenIn != wmatic) {
                                address pool = uniswapV3Factory.getPool(
                                    tokenIn,
                                    wmatic,
                                    1e4
                                );
                                if (pool == address(0x0)) {
                                    pool = uniswapV3Factory.getPool(
                                        tokenIn,
                                        wmatic,
                                        3e3
                                    );
                                }
                                if (pool == address(0x0)) {
                                    pool = uniswapV3Factory.getPool(
                                        tokenIn,
                                        wmatic,
                                        5e2
                                    );
                                }
                                if (pool != address(0x0)) {
                                    (
                                        uint160 sqrtPriceX96,
                                        ,
                                        ,
                                        ,
                                        ,
                                        ,

                                    ) = IUniswapV3Pool(pool).slot0();
                                    uint256 maticPrice = tokenIn < wmatic
                                        ? mulDiv(
                                            uint256(sqrtPriceX96),
                                            uint256(sqrtPriceX96) * output,
                                            FixedPoint96.Q96 * FixedPoint96.Q96
                                        )
                                        : mulDiv(
                                            (FixedPoint96.Q96 *
                                                FixedPoint96.Q96) /
                                                uint256(sqrtPriceX96),
                                            output,
                                            uint256(sqrtPriceX96)
                                        );
                                    if (maticPrice > gasThreshold) {
                                        console.log(
                                            tokenIn,
                                            tokenOut,
                                            fee0,
                                            fee1
                                        );
                                        console.logInt(amountCalculatedIn);
                                        console.log(output);
                                        console.log(maticPrice);
                                        address pool0 = uniswapV3Factory
                                            .getPool(tokenIn, tokenOut, fee0);
                                        address pool1 = uniswapV3Factory
                                            .getPool(tokenIn, tokenOut, fee1);
                                        bytes memory route = abi.encodePacked(
                                            tokenIn,
                                            amountCalculatedIn,
                                            uint8(1),
                                            pool0,
                                            zeroForOne ? uint8(1) : uint8(0),
                                            tokenOut,
                                            uint8(1),
                                            pool1,
                                            zeroForOne ? uint8(0) : uint8(1)
                                        );
                                        try
                                            flashRouteProcessor2.processRoute(
                                                route
                                            )
                                        {} catch {}
                                    }
                                } else {
                                    console.log(tokenIn, tokenOut, fee0, fee1);
                                    console.logInt(amountCalculatedIn);
                                    console.log(output);
                                    console.log(
                                        "no pool for correct matic price"
                                    );
                                }
                            } else {
                                if (output > gasThreshold) {
                                    console.log(tokenIn, tokenOut, fee0, fee1);
                                    console.logInt(amountCalculatedIn);
                                    console.log(output);
                                    address pool0 = uniswapV3Factory.getPool(
                                        tokenIn,
                                        tokenOut,
                                        fee0
                                    );
                                    address pool1 = uniswapV3Factory.getPool(
                                        tokenIn,
                                        tokenOut,
                                        fee1
                                    );
                                    bytes memory route = abi.encodePacked(
                                        tokenIn,
                                        amountCalculatedIn,
                                        uint8(1),
                                        pool0,
                                        zeroForOne ? uint8(1) : uint8(0),
                                        tokenOut,
                                        uint8(1),
                                        pool1,
                                        zeroForOne ? uint8(0) : uint8(1)
                                    );
                                    try
                                        flashRouteProcessor2.processRoute(route)
                                    {} catch {}
                                }
                            }
                        }
                    }
                }
            }
        }
        vm.stopBroadcast();
    }

    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        unchecked {
            uint256 twos = (type(uint256).max - denominator + 1) & denominator;
            // Divide denominator by power of two
            assembly {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the precoditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
            return result;
        }
    }
}
