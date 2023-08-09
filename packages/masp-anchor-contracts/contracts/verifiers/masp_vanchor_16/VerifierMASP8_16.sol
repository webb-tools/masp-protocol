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
		return
			G2Point(
				[
					11559732032986387107991004021392285783925812861821192530917403151452391805634,
					10857046999023057135944570762232829481370756359578518086990519993285655852781
				],
				[
					4082367875863433681332203403145435568316851327593401208105741076214120093531,
					8495653923123431417604973247489272438418190587263600148770280649306958101930
				]
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
		if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
		return G1Point(p.X, q - (p.Y % q));
	}

	/// @return r the sum of two points of G1
	function addition(
		G1Point memory p1,
		G1Point memory p2
	) internal view returns (G1Point memory r) {
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
			switch success
			case 0 {
				invalid()
			}
		}
		require(success, "pairing-add-failed");
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
			switch success
			case 0 {
				invalid()
			}
		}
		require(success, "pairing-mul-failed");
	}

	/// @return the result of computing the pairing check
	/// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
	/// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
	/// return true.
	function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
		require(p1.length == p2.length, "pairing-lengths-failed");
		uint elements = p1.length;
		uint inputSize = elements * 6;
		uint[] memory input = new uint[](inputSize);
		for (uint i = 0; i < elements; i++) {
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
			success := staticcall(
				sub(gas(), 2000),
				8,
				add(input, 0x20),
				mul(inputSize, 0x20),
				out,
				0x20
			)
			// Use "invalid" to make gas estimation work
			switch success
			case 0 {
				invalid()
			}
		}
		require(success, "pairing-opcode-failed");
		return out[0] != 0;
	}

	/// Convenience method for a pairing check for two pairs.
	function pairingProd2(
		G1Point memory a1,
		G2Point memory a2,
		G1Point memory b1,
		G2Point memory b2
	) internal view returns (bool) {
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
		G1Point memory a1,
		G2Point memory a2,
		G1Point memory b1,
		G2Point memory b2,
		G1Point memory c1,
		G2Point memory c2
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
		G1Point memory a1,
		G2Point memory a2,
		G1Point memory b1,
		G2Point memory b2,
		G1Point memory c1,
		G2Point memory c2,
		G1Point memory d1,
		G2Point memory d2
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

contract VerifierMASP8_16 {
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
			[
				4252822878758300859123897981450591353533073413197771768651442665752259397132,
				6375614351688725206403948262868962793625744043794305715222011528459656738731
			],
			[
				21847035105528745403288232691147584728191162732299865338377159692350059136679,
				10505242626370262277552901082094356697409835680220590971873171140371331206856
			]
		);
		vk.gamma2 = Pairing.G2Point(
			[
				11559732032986387107991004021392285783925812861821192530917403151452391805634,
				10857046999023057135944570762232829481370756359578518086990519993285655852781
			],
			[
				4082367875863433681332203403145435568316851327593401208105741076214120093531,
				8495653923123431417604973247489272438418190587263600148770280649306958101930
			]
		);
		vk.delta2 = Pairing.G2Point(
			[
				7543043102863481200406860595501377566538427138067389692909788335845884760675,
				17217887234535090955905219007584098241196779967040401013973650157998479990120
			],
			[
				10761527866653843721172949963425315880975645635361431972194893797562055496275,
				7374850093914230764565655083795350451895094256679502908573074184589644651867
			]
		);
		vk.IC = new Pairing.G1Point[](46);

		vk.IC[0] = Pairing.G1Point(
			8979879675114205092696370768887846019099398585090989528353269278380972832536,
			6170795415826920949563568117695564015773540284732452190929436548429111781228
		);

		vk.IC[1] = Pairing.G1Point(
			1194143988422789746209113480031397520031786199812951185631838906384325417726,
			12571461268805801462546461921391699336181743277044198031203217067706338756869
		);

		vk.IC[2] = Pairing.G1Point(
			11706916401005946131854540292467636260042370028498097945847279766543584694968,
			14298689417617813491275310522537430829173128946387060634037658513835708171761
		);

		vk.IC[3] = Pairing.G1Point(
			20586853015197692661141965612340789535319547928627565372173599666214040354512,
			20444136173805180545772897046560857482658770314943188270610394457313581343172
		);

		vk.IC[4] = Pairing.G1Point(
			6180480489314324983644582886998770398316170818192831482841536501071976248849,
			8173366041629458466578257332758199242452931361737891336925423308462388816553
		);

		vk.IC[5] = Pairing.G1Point(
			6361902171849882728766879022135832251669645241706049540589154703634701112788,
			5912685326994859714737158468277841496759989605130630855922864463946990065376
		);

		vk.IC[6] = Pairing.G1Point(
			3427425461096583731132382393270422958560581868769974356181554161718502700895,
			8867477099768960999908848253250221188225712408345343105207863471961183762626
		);

		vk.IC[7] = Pairing.G1Point(
			20415683514872924423885785251029610507118594436925940794662715836650754287648,
			8237715234300999234616054692662004264189915092398439285242467186916874778643
		);

		vk.IC[8] = Pairing.G1Point(
			5138402767557851411311227594388656793307336338692352856752464737665507558053,
			15454189580571272769624665969000724263882475544727773744841626543219160841945
		);

		vk.IC[9] = Pairing.G1Point(
			5882190721648359486598237070251318202947736085335992954172279737092257229448,
			2805369717928231323234592165597027419835157402680994906643394380199507700145
		);

		vk.IC[10] = Pairing.G1Point(
			3032390490294504120514525299012344535514257237015892631122176470125309677044,
			12305349203249937722325118867950472855884138299893044935138265482813161830951
		);

		vk.IC[11] = Pairing.G1Point(
			4296460779630956411228829040589070501302932864543829708737658789189792258810,
			8392254295395326380881573229875474612901235515624747128615577605006037864115
		);

		vk.IC[12] = Pairing.G1Point(
			7967377697377949771650286744612502541457164170053775866283415191240507893447,
			811643639196909719512996494015673498418384045509513258703091727708393560505
		);

		vk.IC[13] = Pairing.G1Point(
			15860700298512067695632702971043334544121344180805517383327596746000368894858,
			5145658397888008484827328867919382346754178166964126143437707249897093773295
		);

		vk.IC[14] = Pairing.G1Point(
			2388061040708713592279520536005828563854683521307307400029783641385350513818,
			3378295821669415568338710047136055295592732308392017207694979312431240253041
		);

		vk.IC[15] = Pairing.G1Point(
			13559431662866265170329844569379748293802894130468257084828706469664437951128,
			13775277562320889472340046921215626054725558661964738982917061430430517089452
		);

		vk.IC[16] = Pairing.G1Point(
			5722121073701534251278532035074951378057869238237185263870429559834153769080,
			6571035615906359820041040467068403661294408916511778642705337005483613380339
		);

		vk.IC[17] = Pairing.G1Point(
			15121644419870827976444721426726696395069456015736095112524927829415777819423,
			4786644159473614692815907827947557355945275218721069954234615585543740809375
		);

		vk.IC[18] = Pairing.G1Point(
			8317787687179169163018903217223970046654258747262861681734559460301801241311,
			7622372677882874529957497171092911074837422060325667367547819203341347907882
		);

		vk.IC[19] = Pairing.G1Point(
			16464917221518815209032783642779944183763866471663324802889118509162235950315,
			9583671033787198876333033989343935399247948732679938715841737385129195242776
		);

		vk.IC[20] = Pairing.G1Point(
			7798839253973106691899859289599864414188782272055988254175326734396006326676,
			19287569181824262688326240376726143905001177682922672082155652479954903478304
		);

		vk.IC[21] = Pairing.G1Point(
			5175040419597576644589721949514355293395938804305301719457257915181094253335,
			16673834810044688376357482728423076768654616331572728796083975898182260736792
		);

		vk.IC[22] = Pairing.G1Point(
			4883853023059324410906557365975387327179637782451563940182380654457991318898,
			18295311982504533553563525807193179535210607098965555842375671372930790478141
		);

		vk.IC[23] = Pairing.G1Point(
			4502418744226747380504378914464269870991630027446992386162217251865255144400,
			21465369950750190332646642318390317050987008109872723218742805698306400943346
		);

		vk.IC[24] = Pairing.G1Point(
			12664329357912455191733338630394570048349854898756507129816701473071748898122,
			10401634817132668460114990004624400658884860141276455072674983675050295056779
		);

		vk.IC[25] = Pairing.G1Point(
			4795211255819758365641917459445569869053626261103769958754435723950229737372,
			14055323751523196897386808058408597383549220638612889005524737570908302544380
		);

		vk.IC[26] = Pairing.G1Point(
			19115349175771981810550323932121712920178432849173475422904268986291564011357,
			8603012191261580842943215413611526356040817356590473554965756296905301373329
		);

		vk.IC[27] = Pairing.G1Point(
			18469814242192933625793819606511324532936662977831087258637078050485761198739,
			17660243725616495174351485651404019745086794806839930493298624234919594003058
		);

		vk.IC[28] = Pairing.G1Point(
			6774631340194404284364534470461234339947497923090773262666243046921826820070,
			4002866052691905165674092909863555564694556632567505089339517653435796690609
		);

		vk.IC[29] = Pairing.G1Point(
			6807060034293300278714010314089697855364378183314677125171231514279575008135,
			336451960063641739468183740392720129911941770289378754909861982130562149932
		);

		vk.IC[30] = Pairing.G1Point(
			20307952077632571995728693556423862726223822095465227695142887428387983516917,
			2408447586465852657396147878485009212089902593743520027347511619610931203841
		);

		vk.IC[31] = Pairing.G1Point(
			17198695033757597983073495042615145052168655726845215747457803877597643421438,
			1142301068698768942977739581217632223726109104735695859793955192147276434108
		);

		vk.IC[32] = Pairing.G1Point(
			7723406208898317691071065570871603538232368628307354843909583286414337207570,
			4358383715025869554334942002776005323278001642305683140909991557406507440751
		);

		vk.IC[33] = Pairing.G1Point(
			2419320992894390750018405464674701261521975777550115012583353051815056870675,
			20525246080597601076157242500470212925931331694788703281045908575626218669327
		);

		vk.IC[34] = Pairing.G1Point(
			9467530392882875232625434380674112631552870938524869738546457280965199561806,
			15027141475825102192177952371902705568956330303040788876385660572453372094923
		);

		vk.IC[35] = Pairing.G1Point(
			8128092148499170740300134329705184337142726391655022667923057517090115384469,
			51008595263727925711208888132183738433577040838205185981239778765754885223
		);

		vk.IC[36] = Pairing.G1Point(
			17775014316828216271507280443464311226628137525634889573754503027614264585248,
			19649194295655971819903060433155588000469704590746246241280929449124146995841
		);

		vk.IC[37] = Pairing.G1Point(
			1493203288032145669482463023832180748999729160317696419408713421879295833498,
			18250922092984595028041345308908942147456427144620960545203208729524026316428
		);

		vk.IC[38] = Pairing.G1Point(
			8331172104573444902424107026993306935761056429991657574079384456784586503079,
			561750898768123224268671769203527445981806928127739249114814580449507349368
		);

		vk.IC[39] = Pairing.G1Point(
			8150103540486911883088158741222455545363855519615525285974676303103872478607,
			5332900812120425363879115635728559449176324022925348074744021866100045037698
		);

		vk.IC[40] = Pairing.G1Point(
			7272606129938085218862634675918902605804951320680545260932935086540849196871,
			13339631564062140574446277532439548374109873795870056314927838501762616315787
		);

		vk.IC[41] = Pairing.G1Point(
			12612114118667383750996816859504221960039322504997109148090269120617144015744,
			16793966335770952219497489820899806419310809445057852440650183283265998572788
		);

		vk.IC[42] = Pairing.G1Point(
			19942762429080607014525161443804849628064806043406028693582336618046375050506,
			15537211475164831949786802408032679305623875068997780568113791200604551951993
		);

		vk.IC[43] = Pairing.G1Point(
			8261746318366488962261176407907571733736352934546908863096532833801771962647,
			910220880745775941350562379903083069160497434146062759583694937589196190705
		);

		vk.IC[44] = Pairing.G1Point(
			18566163219065924106125130727597641745511990586063606817013498747115396985717,
			17823699680180841878696177430018535558873493021122347569322819082280377987631
		);

		vk.IC[45] = Pairing.G1Point(
			20679364987216966661445944945178727858747913480765848776213040843746406334585,
			18427925128693417553040871451563935083944621948280476784180803031240924000428
		);
	}

	function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
		uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
		VerifyingKey memory vk = verifyingKey();
		require(input.length + 1 == vk.IC.length, "verifier-bad-input");
		// Compute the linear combination vk_x
		Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
		for (uint i = 0; i < input.length; i++) {
			require(input[i] < snark_scalar_field, "verifier-gte-snark-scalar-field");
			vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
		}
		vk_x = Pairing.addition(vk_x, vk.IC[0]);
		if (
			!Pairing.pairingProd4(
				Pairing.negate(proof.A),
				proof.B,
				vk.alfa1,
				vk.beta2,
				vk_x,
				vk.gamma2,
				proof.C,
				vk.delta2
			)
		) return 1;
		return 0;
	}

	/// @return r  bool true if proof is valid
	function verifyProof(
		uint[2] memory a,
		uint[2][2] memory b,
		uint[2] memory c,
		uint[45] memory input
	) public view returns (bool r) {
		Proof memory proof;
		proof.A = Pairing.G1Point(a[0], a[1]);
		proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
		proof.C = Pairing.G1Point(c[0], c[1]);
		uint[] memory inputValues = new uint[](input.length);
		for (uint i = 0; i < input.length; i++) {
			inputValues[i] = input[i];
		}
		if (verify(inputValues, proof) == 0) {
			return true;
		} else {
			return false;
		}
	}
}
