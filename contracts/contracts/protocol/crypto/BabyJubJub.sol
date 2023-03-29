// SPDX-License-Identifier: GPL
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
// Implementer name - yondonfu
// Link to the implementation - https://github.com/yondonfu/sol-baby-jubjub/blob/master/contracts/CurveBabyJubJub.sol
pragma solidity ^0.8.16;
import "../../common/Types.sol";

library BabyJubJub {
    // Curve parameters
    // E: 168700x^2 + y^2 = 1 + 168696x^2y^2
    // A = 168700
    uint256 public constant A = 0x292FC;
    // D = 168696
    uint256 public constant D = 0x292F8;
    // Prime Q = 21888242871839275222246405745257275088548364400416034343698204186575808495617
    // slither-disable-next-line too-many-digits
    uint256 public constant Q =
        0x30644E72E131A029B85045B68181585D2833E84879B9709143E1F593F0000001;

    // @dev Base point generates the subgroup of points P of Baby Jubjub satisfying l * P = O.
    // That is, it generates the set of points of order l and origin O.
    // slither-disable-next-line too-many-digits
    uint256 public constant BASE8_X =
        5299619240641551281634865583518297030282874472190772894086521144482721001553;
    // slither-disable-next-line too-many-digits
    uint256 public constant BASE8_Y =
        16950150798460657717958625567821834550301663161624707787222815936182638968203;

    /**
     * @dev Add 2 points on baby jubjub curve
     * Formulae for adding 2 points on a twisted Edwards curve:
     * x3 = (x1y2 + y1x2) / (1 + dx1x2y1y2)
     * y3 = (y1y2 - ax1x2) / (1 - dx1x2y1y2)
     */
    function pointAdd(G1Point memory g1, G1Point memory g2)
        internal
        view
        returns (G1Point memory)
    {
        uint256 x3 = 0;
        uint256 y3 = 0;
        if (g1.x == 0 && g1.y == 0) {
            return G1Point(x3, y3);
        }

        if (g2.x == 0 && g1.y == 0) {
            return G1Point(x3, y3);
        }

        uint256 x1x2 = mulmod(g1.x, g2.x, Q);
        uint256 y1y2 = mulmod(g1.y, g2.y, Q);
        uint256 dx1x2y1y2 = mulmod(D, mulmod(x1x2, y1y2, Q), Q);
        uint256 x3Num = addmod(mulmod(g1.x, g2.y, Q), mulmod(g1.y, g2.x, Q), Q);
        uint256 y3Num = submod(y1y2, mulmod(A, x1x2, Q), Q);

        x3 = mulmod(x3Num, inverse(addmod(1, dx1x2y1y2, Q)), Q);
        y3 = mulmod(y3Num, inverse(submod(1, dx1x2y1y2, Q)), Q);
        return G1Point(x3, y3);
    }

    /**
     * @dev Perform modular subtraction
     */
    function submod(
        uint256 _a,
        uint256 _b,
        uint256 _mod
    ) internal pure returns (uint256) {
        uint256 aNN = _a;

        if (_a <= _b) {
            aNN += _mod;
        }

        return addmod(aNN - _b, 0, _mod);
    }

    /**
     * @dev Compute modular inverse of a number
     */
    function inverse(uint256 _a) internal view returns (uint256) {
        // We can use Euler's theorem instead of the extended Euclidean algorithm
        // Since m = Q and Q is prime we have: a^-1 = a^(m - 2) (mod m)
        return expmod(_a, Q - 2, Q);
    }

    /**
     * @dev Helper function to call the bigModExp precompile
     */
    function expmod(
        uint256 _b,
        uint256 _e,
        uint256 _m
    ) internal view returns (uint256 o) {
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            let memPtr := mload(0x40)
            mstore(memPtr, 0x20) // Length of base _b
            mstore(add(memPtr, 0x20), 0x20) // Length of exponent _e
            mstore(add(memPtr, 0x40), 0x20) // Length of modulus _m
            mstore(add(memPtr, 0x60), _b) // Base _b
            mstore(add(memPtr, 0x80), _e) // Exponent _e
            mstore(add(memPtr, 0xa0), _m) // Modulus _m

            // The bigModExp precompile is at 0x05
            let success := staticcall(gas(), 0x05, memPtr, 0xc0, memPtr, 0x20)
            switch success
            case 0 {
                revert(0x0, 0x0)
            }
            default {
                o := mload(memPtr)
            }
        }
        // solhint-enable no-inline-assembly
    }

    function mulPointEscalar(G1Point memory point, uint256 scalar)
        internal
        view
        returns (G1Point memory r)
    {
        r.x = 0;
        r.y = 1;

        uint256 rem = scalar;
        G1Point memory exp = point;

        while (rem != uint256(0)) {
            if ((rem & 1) == 1) {
                r = pointAdd(r, exp);
            }
            exp = pointAdd(exp, exp);
            rem = rem >> 1;
        }
        r.x = r.x % Q;
        r.y = r.y % Q;

        return r;
    }
}
