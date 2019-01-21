// Copyright (c) 2009-2010 Satoshi Nakamoto
// Copyright (c) 2009-2015 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include "primitives/block.h"

#include "hash.h"
#include "tinyformat.h"
#include "utilstrencodings.h"
#include "crypto/common.h"
#include "crypto/neoscrypt.h"
#include "crypto/Lyra2Z/Lyra2Z.h"
#include "consensus/consensus.h"
#include "chainparams.h"

#define TIME_MASK 0xffffff80

// used for all blocks after genesis
uint256 CBlockHeader::GetHash() const
{
    uint256 thash;
    unsigned int profile = 0x0;

    if (nTime > Params().GetConsensus().nX16rtTimestamp) {
        //x16rt
        int32_t nTimeX16r = nTime&TIME_MASK;
        uint256 hashTime = Hash(BEGIN(nTimeX16r), END(nTimeX16r));
        thash = HashX16R(BEGIN(nVersion), END(nNonce), hashTime);
    } else if (nTime > LYRA2Z_TIMESTAMP) {
        //lyra2z
        lyra2z_hash(BEGIN(nVersion), BEGIN(thash));
    } else {
        //neoscrypt
        neoscrypt((unsigned char *) &nVersion, (unsigned char *) &thash, profile);
    }

    return thash;
}

// used for genesis generation only
uint256 CBlockHeader::GetHash(const bool noConsensus) const
{
    uint256 thash;
    unsigned int profile = 0x0;
    
    //neoscrypt
    neoscrypt((unsigned char *) &nVersion, (unsigned char *) &thash, profile);

    return thash;
}

std::string CBlock::ToString() const
{
    std::stringstream s;
    s << strprintf("CBlock(hash=%s, ver=%d, hashPrevBlock=%s, hashMerkleRoot=%s, nTime=%u, nBits=%08x, nNonce=%u, vtx=%u)\n",
        GetHash().ToString(),
        nVersion,
        hashPrevBlock.ToString(),
        hashMerkleRoot.ToString(),
        nTime, nBits, nNonce,
        vtx.size());
    for (unsigned int i = 0; i < vtx.size(); i++)
    {
        s << "  " << vtx[i].ToString() << "\n";
    }
    return s.str();
}
