PTAU_PATH=./powersOfTau28_hez_final_22.ptau

compile_phase2 () {
    local outdir="$1" circuit="$2" pathToCircuitDir="$3"
    echo $outdir;
    mkdir -p $outdir;

    echo "Setting up Phase 2 ceremony for $circuit"
    echo "Outputting ${circuit}_circuit_final.zkey and ${circuit}_verifier.sol to $outdir"

    npx snarkjs groth16 setup "$pathToCircuitDir/$circuit.r1cs" $PTAU_PATH "$outdir/${circuit}_circuit_0000.zkey"
    echo "test" | npx snarkjs zkey contribute "$outdir/${circuit}_circuit_0000.zkey" "$outdir/${circuit}_circuit_0001.zkey" --name"1st Contributor name" -v
    npx snarkjs zkey verify "$pathToCircuitDir/$circuit.r1cs" $PTAU_PATH "$outdir/${circuit}_circuit_0001.zkey"
    npx snarkjs zkey beacon "$outdir/${circuit}_circuit_0001.zkey" "$outdir/${circuit}_circuit_final.zkey" 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
    npx snarkjs zkey verify "$pathToCircuitDir/$circuit.r1cs" $PTAU_PATH "$outdir/${circuit}_circuit_final.zkey"
    npx snarkjs zkey export verificationkey "$outdir/${circuit}_circuit_final.zkey" "$outdir/${circuit}_verification_key.json"  

    npx snarkjs zkey export solidityverifier "$outdir/${circuit}_circuit_final.zkey" $outdir/${circuit}_verifier.sol
    echo "Done!\n"
}

move_verifiers_and_metadata_masp_vanchor () {
    local indir="$1" size="$2" anchorType="$3" nIns="$4"
    local verifier_rename="VerifierMASP_${size}_${nIns}"
    cp $indir/${anchorType}_${nIns}_${size}_circuit_final.zkey solidity-fixtures/solidity-fixtures/$anchorType/$size/${anchorType}_${nIns}_${size}_circuit_final.zkey

    mkdir -p packages/masp-anchor-contracts/contracts/verifiers/$anchorType
    cp $indir/${anchorType}_${nIns}_${size}_verifier.sol packages/masp-anchor-contracts/contracts/verifiers/$anchorType/VerifierMASP"$size"_"$nIns".sol
    perl -i -pe 's/contract Verifier/contract VerifierMASP'$size'_'$nIns'/g' packages/masp-anchor-contracts/contracts/verifiers/$anchorType/VerifierMASP"$size"_"$nIns".sol
    perl -i -pe 's/pragma solidity \^0.6.11;/pragma solidity \^0.8.18;/g' packages/masp-anchor-contracts/contracts/verifiers/$anchorType/VerifierMASP"$size"_"$nIns".sol
}
