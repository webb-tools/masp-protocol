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
contract VerifierMASP2_16 {
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
            [19654433648249091423939475630489633850060210974826188437250930625988363854721,
             21433257456481500060693975510576054052487548277245761062180496173829761022702],
            [9363905633886860167457420403780700854396825226677030649703568403607157230981,
             14436349344599732919739634901982332048250645584421052058369241519606714540341]
        );
        vk.IC = new Pairing.G1Point[](40);
        
        vk.IC[0] = Pairing.G1Point( 
            14912077067399789037273980598086708575836312963186824764135183597276562215535,
            2159053323734412145295798160635515077906963812347266869609854787718205781852
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            21549336481269637277197750454927140561561748739778680110003789785656998735506,
            13354656332949245188692721676902444329552690318043739096942998254177606760102
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            11333680328833010202105748696589643406018897848237859159209925969995564761735,
            14683288979087304472210516167672862349458898123991314926912995202965846180092
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            13345811161364911688431364955955489457167018523283798112902704611162271667636,
            9024450822762551196455272613928150826770900192837989975436619885982185995175
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            6885907966306361505925617965480551553571517615952392449002515223285003798030,
            18474070143342516252267393264445661365880818772307274529993322424656163399232
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            9880641903823112751833154466311447806340397825259333438165056414992883344365,
            9811435510285189712111534668459586527210688336703494278349936447034877870827
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            2711338009761304562956484271183642256705794107495628719366506785948445474349,
            3721548900474128167839599894646585920806813680863944160055833315359492570479
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            5409301369277939326098537913557250139477095064163598548887701231869419002633,
            14922961238662282274094623418884251618120191495188937589090614783455060095865
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            3082434378225177319451430597269623218451266284397784386381778351044967873214,
            14127631421418794472568403529093986702541129640715278780295635093764023904088
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            13010720347119510291703716059750592698715358735136515129455667602825285570579,
            19418941480339814658392167841056483270494610273113714678765097820702311275244
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            13788550430238561493961689971429425526082824762023991634165637503444475192258,
            4614817496720216657661162036780582502880822018750664101842388245711251296831
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            16808841905540589055031298173074361582121773110716323950562865082082872339331,
            2388656989330645088565356119274381884818524381115148750998742349810339721862
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            15673527172448018914285913649917996172197172206291396376020983620653620464134,
            19097981320480860062846910112065528125944210102009895462787524418037420943945
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            19605116251496756351484955274022777291168590249979996077449291374314443491925,
            20081782008199135167587378834271309417321603278499319692691506749762103183512
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            11345222779422008595557774168356983722336844477447937593899876995790922289975,
            5039644585621027692404955603222007068015155747804395649161078044216926485040
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            8434857640466908775315708181500175966788655249359364421092418954885953648538,
            2654787109024282402668515969164758618427766355183580964974112027197446835567
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            16882075474829795215893863958448307625697896138398194766851474676496986513166,
            4800409668679096414007412416648817849097705019784481012700935232287433382576
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            13124958720558037657224409220104605983680129416994964084055932222246730331572,
            20523645213534256903419041969517267090105674208251504172473712191177342248773
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            16331717125624381305816054448124917310069380892418557198841355903631692197294,
            6762421722143513990133880195623977702987546083779399724777916484596362515702
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            12210419349171325170152518800180782929094786827352907321415291501896958737638,
            17350135698405896413483831105091705973690943834349675257347046412024314096851
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            6996959642373976837490027330498039471790880259943023518936047926041175599904,
            15075265207777182170646979415716147182719547414958052332864353158437552998615
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            6904108410778095966802659684051668699705217189001686379364058532170003661734,
            10844155908736750092684856260105254245461359329661228680370152219983414030238
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            10785564213913036383386388840558938460899210122135169559219489265501881268018,
            8899629236786333176835324817508385749919882843041430786654330940660603330090
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            18468031644233890259460676330679538242565784951482864188885448076621161415865,
            6759926841164712252119351198011843015420996000553868238490686410860809558602
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            20472106403517729252583998161855157398983519328107423063072622124591369476281,
            6345762969062401452133839507545640164690926485500180274100887653365936689777
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            17444163030371809303153412827981170394839416778840959574629834603647466543531,
            241929190438852581846155338995736537915447668088899044753190513936024319739
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            2184440699022159650188696927805674277033765968713130372598386944268216034031,
            2700693565528638237551680470140673287389087527647081401474470130553195364677
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            21320876546365250828069279248976573195531924114861400534266335339352712832337,
            16303972327525702129319665571268545046942969779046348966955464064413858956047
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            10101099173493167023638489143374160287947463539696025220277596692787507188607,
            19564308347369974327582558290982494737930588079739276127100813319405024340642
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            19055819553400125142726220741548917085182786237076352347599396936834376184173,
            19813714043200874688695061024435874323237675925345193667083815326797527316501
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            2474595586031070733278571921431853118078585707430713224874349691114326497589,
            9291795226239723523471615384455712739304491792566866267151652804187738426705
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            18315657993024199753796757235303811640388518661373558219919138752377826841239,
            9735274763334079308252925846995738947713518091668816398340153660695947619811
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            6247080630819515882216064738061296701636677469032321235087623617014320368362,
            18067750714074363361184264716490688426307395715080354535843168294710728452776
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            13383882897282897016583271632538580114375437764645860056060177938675200321923,
            21816897601587925984286341939123504846756388927605335684656317380764211187249
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            10310229063551290019758535196618269005130707314297913554573304576762811440544,
            17207031883275509124387500803358575503555233326667628696677901750914178551033
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            6480030235511992036230949783330564160664355378472703302714126708138031867063,
            10095251670332205344378794080142259395427649678738113619180470801381836535663
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            1689279124557878912673895579926951146524309199188969304489465677514079350561,
            3941724136204658868141948085784426792771767907758075580061222232537766730816
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            116985911071933044473554993281180086678043500546835401581427122346492987733,
            1062664343710761932177634384014452182891448540060334098491012370676387781099
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            5482764109007773163026673286712700472902628210972956743308676138255437843797,
            2637035257613549563888040822588328038466878325870732678810374089211887478432
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            16976090262916421407806836478816776767285617348201181321629531447147609505649,
            8413148947718774639355574713991460999119149674823292357185453439285020065273
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
