//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract VerifierReward_30_8 {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [11178479508089217319746222595913509989451991440853387097765025841488808828458,
             6987196829798874634256824179596823799905904516407430909900049378510435449258],
            [1767903049673724250662923760199990180373861931225172323203029719219856586140,
             21853321852130031631033001192689920196000068134182096248153809719998518098356]
        );
        vk.IC = new Pairing.G1Point[](40);
        
        vk.IC[0] = Pairing.G1Point( 
            1903912385381818871513544544218993987076569300975201314401256271641881457346,
            14035496493458408536177991606665220700739985689415620446467902107704141571267
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            6293542275438812388244444638219657035809242627309745145595518994251635229943,
            19175505325099873080416295561538259583258992405167171524064885539724663473962
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            6985940510680927394224769779868849785174540378527363587397722172052183454363,
            2776911601023936053596629068011585749094971413795463813740342320654744285891
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            10673579542635852459992447799871873277955202926145757805452549705756559431522,
            302193597902401065752783806875209008578260168597878032243872879390177572179
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            11104159667247560721459505320840747966383778633906196196253705710340810920899,
            9421563019058605870329247109447433430887806504360196882675831255562913441052
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            10639015422017752493562725982458819608778178474450169541857149453330399237104,
            13533725014107358952056466342353547723785559161621150733488227844639629377776
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            9587689317054295901295619872410842582973580330559967513877976019134341053813,
            4922426396829689550031856925704827339439912097831145250977231500926130826473
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            17750647336184566823035633650751028160514715792110087454595755491337494611072,
            18071648929075643658168482554357613379077089246808934547464946203792908136381
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            16050695477376477097814757435034426321328829229576906902731743814173629305902,
            9793206183322839417020893943377214380999597366979595986608835224967157148109
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            11107200536234346886797886862327611458203078975762084794618325311576916543169,
            10620155682385605041102476734736777813773902576082294271354955731143369364604
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            12049571012736933932194956944770027529799665343513791867732363465239895701280,
            17502984440210431314958228301516987507053132252338138260414356216711404249680
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            11826827252747096299332199330795160421982777429432469535230819991431657070002,
            2955880546221854950150796727527904121808567660105564059258392493235785073886
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            7871364303320522430624506059891887552513519881096058875376421369421130604905,
            3536011809407036579775196573535120573127711979167319744230735125808251704749
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            14351286541766001109921027496644275674137665018196987443304766911090635344943,
            14805694593964037975879771513747709954766946294541554652709079735078455094951
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            6315810100787788137110149790189295898561215731734085744849569239618605322960,
            8027801967540198231655814391484235732625001631133480929364573841389117218623
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            6748072402930615053387248472553340922812534846094443768970463694666606570255,
            13921219593987765727193768304721248419758586158637991765708969832316153804156
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            10617566788937300305232602696365415443483418991665274484565009933033077484515,
            10481383202860356679696853938019351858206141230648168612369000428738776998842
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            17294280740163490904622810685189742242006741871866078192855170446225113308744,
            19961270288803913203947412325967657714997018045969355312192783985445899740968
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            6491742982332785655683228453617139688820860775736180192890650013287495221426,
            4102015599516926685681988771967177554059769827131008223490865824253347371705
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            10419792659617712529044133177763979251161800727827504962975980256327430540518,
            1712068599917528287751267838757339253357490601980598887805827328163764484360
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            1917375190384322457544733807341645284735110399119014386015683645489169423569,
            19322974355911607081540118903964728435931805775108991533146217454778783449258
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            14201404370251753591518645233466231378429765316257338956971749399807544126070,
            4303671659074613785017514960717570419359295505191296555471154430871332505958
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            5956735607845795961749450865037207920544575157225099629897490935722114944320,
            4447675147923050417093430852124653933720124204217200336036372684204422358460
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            9300749045360975354816967726011138284156833159160586834810652368153745236660,
            20080154244762476650819581524390775394298796401856649369521895670043272422824
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            74547790682759596481774549889234228015514261130494698154771922374098090496,
            16816683496813166427595013646972223936216209889120637479334046525742936772471
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            16700184389097821384956731104185663009289434967812022821679738513854428910122,
            2690642489811887249354276502881598816751109090500509596544598855219581778617
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            6442043762954223352584599156482933683460283599635142543324475253126323327937,
            20950939855428165800730292358452187426732964925927173555583015606091440718204
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            13357694790702205362562604415678461322979738685540556264648633010532258138086,
            20436186975450415777347836419346857770327453719118962258345524180941959791313
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            7615714506860124694990160415791448910079244759621259498264230892566679613920,
            9783193137482934379276710431224248713817622744283704761844205006076113028516
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            13510750920590338302520396366930820148451182552694479472808513749275981613469,
            10066795484349810827817160410279570924476883426304932135405406617310314649435
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            8258220129357709726714949202246484233094089874004805312498452653481928762530,
            4841473090140963225592379846328640727466156804396463863330288345709984124584
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            18622984713561633235242931996312856396184992455278243261008935978311321488596,
            10274148118518086360225999998341872462092209552837926661978492392982391483879
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            8993256906674443533360660816142052274763193434993890598338166486687679112138,
            19183320912244382115780963393348522696470749715129679787617119534783578777617
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            10030087370880560325210655933176625190764486255249920139395975228287700012114,
            6879029545627083641959457366127820154219955480503232644047493045760518658431
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            5888977383923685037570545828858780973999225550497047218672748598125929390682,
            13835323086414285504719277623622584207322008681945845377372440787572148431802
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            7253353629419777994526765846297810538514014566756573463900247105405341885297,
            16073517412762725337819577963320704969187211101731339638642819436214821769688
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            9616992289949327703394994890022424354529688167437311927851026086603561768445,
            9049384700808592132926700900772955694951145083255558180297637596089322193763
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            345657869708369328581438768416070290722144620810997420479963800696412468291,
            19286419880391147396616694570877058177360850680127455905593407872827462878208
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            5653763665051465812922997682350378242358206860708975832992488424017048392345,
            8154470003557645479354675222068999305305604589733661534362816248605286541635
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            12807895022867213089305026777247613934070906076863006489049630024099694250108,
            12041651184610161265793065859750607379216028217068242872681952948652823116726
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[39] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
