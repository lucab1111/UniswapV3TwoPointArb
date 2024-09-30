// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/** @notice Simple read stream */
library InputStreamStorage {
    bytes32 constant startPos =
        0x0000000000000000000000000000000000000000000000000000000000000004;

    // POS CONSTANTS GETS CHANGED, GAS INEFFICIENT, MAYBE STORE IN MEMORY??

    /** @notice Creates stream from data
     * @param data data
     */
    function createStream(bytes memory data) internal returns (uint256 stream) {
        // assembly {
        //     stream := mload(0x40) // set free pointer to stream value
        //     mstore(0x40, add(stream, 64)) // increment free pointer to reserve 62 bytes
        //     mstore(stream, data) // store pointer to data in stream - stream is now pointer to pointer to data
        //     let length := mload(data) // first 32 bytes of data is the length, so we are loading this, bytes after are the actual values
        //     mstore(add(stream, 32), add(data, length)) // stores address of data plus length of data, to get address where data ends or pointer to where it ends
        // }
        uint256 length;

        assembly {
            stream := startPos
            // sstore(stream, data)
            sstore(stream, mul(add(stream, 2), 32))
            length := mload(data)
            sstore(add(stream, 1), length)
        }
        uint steps = (length % 32 != 0 ? length / 32 + 1 : length / 32); // rounding up
        for (uint8 i = 0; i < steps; ++i) {
            // Copy all of data into storage -- looking pretty bad ngl
            assembly {
                sstore(
                    add(stream, add(2, i)),
                    mload(add(data, mul(32, add(i, 1))))
                )
            }
        }
    }

    /** @notice Checks if stream is not empty
     * @param stream stream
     */
    function isNotEmpty(uint256 stream) internal view returns (bool) {
        uint256 pos;
        uint256 finish;
        // assembly {
        //     pos := mload(stream)
        //     finish := mload(add(stream, 32))
        // }

        assembly {
            pos := sload(stream)
            finish := add(sload(add(stream, 1)), mul(add(stream, 2), 32))
        }
        return pos < finish;
    }

    /** @notice Reads uint8 from the stream
     * @param stream stream
     */
    function readUint8(uint256 stream) internal returns (uint8 res) {
        // assembly {
        //     let pos := mload(stream)
        //     pos := add(pos, 1)
        //     res := mload(pos)
        //     mstore(stream, pos)
        // }
        uint8 offset;
        uint8 slotNo;
        uint256 resSlot;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 1)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        res = uint8(resSlot >> (256 - offset * 8));
    }

    /** @notice Reads uint16 from the stream
     * @param stream stream
     */
    function readUint16(uint256 stream) internal returns (uint16 res) {
        // assembly {
        //     let pos := mload(stream)
        //     pos := add(pos, 2)
        //     res := mload(pos)
        //     mstore(stream, pos)
        // }
        uint8 offset;
        uint8 slotNo;
        uint256 resSlot;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 2)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        if (offset >= 2) {
            // 2 bytes checked as uint16 is 2 bytes
            res = uint16(resSlot >> (256 - offset * 8));
        } else {
            uint256 nextResSlot;
            assembly {
                nextResSlot := sload(add(slotNo, 1))
            }
            // res = uint16(resSlot >> offset) + uint16(nextResSlot << extra);
            res = uint16(
                (nextResSlot >> (256 - offset * 8)) + (resSlot << (offset * 8))
            ); // not sure if add then cast or vice versa is better
        }
    }

    /** @notice Reads uint24 from the stream
     * @param stream stream
     */
    function readUint24(uint256 stream) internal returns (uint24 res) {
        // assembly {
        //     let pos := mload(stream)
        //     pos := add(pos, 3)
        //     res := mload(pos)
        //     mstore(stream, pos)
        // }
        uint8 offset;
        uint8 slotNo;
        uint256 resSlot;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 3)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        if (offset >= 3) {
            // 3 bytes checked as uint24 is 3 bytes
            res = uint24(resSlot >> (256 - offset * 8));
        } else {
            uint256 nextResSlot;
            assembly {
                nextResSlot := sload(add(slotNo, 1))
            }
            // res = uint24(resSlot >> offset) + uint24(nextResSlot << extra);
            res = uint24(
                (nextResSlot >> (256 - offset * 8)) + (resSlot << (offset * 8))
            ); // not sure if add then cast or vice versa is better
        }
    }

    /** @notice Reads uint32 from the stream
     * @param stream stream
     */
    function readUint32(uint256 stream) internal returns (uint32 res) {
        // assembly {
        //     let pos := mload(stream)
        //     pos := add(pos, 4)
        //     res := mload(pos)
        //     mstore(stream, pos)
        // }
        uint8 offset;
        uint8 slotNo;
        uint256 resSlot;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 4)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        if (offset >= 4) {
            // 4 bytes checked as uint32 is 4 bytes
            res = uint32(resSlot >> (256 - offset * 8));
        } else {
            uint256 nextResSlot;
            assembly {
                nextResSlot := sload(add(slotNo, 1))
            }
            // res = uint32(resSlot >> offset) + uint32(nextResSlot << extra);
            res = uint32(
                (nextResSlot >> (256 - offset * 8)) + (resSlot << (offset * 8))
            ); // not sure if add then cast or vice versa is better
        }
    }

    /** @notice Reads uint256 from the stream
     * @param stream stream
     */
    function readUint(uint256 stream) internal returns (uint256 res) {
        // assembly {
        //     let pos := mload(stream)
        //     pos := add(pos, 32)
        //     res := mload(pos)
        //     mstore(stream, pos)
        // }
        uint8 offset;
        uint8 slotNo;
        uint256 resSlot;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 32)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        if (offset == 0) {
            // Zero offset checked as uint256 is 32 bytes, so whole word size
            res = resSlot;
        } else {
            uint256 nextResSlot;
            assembly {
                nextResSlot := sload(add(slotNo, 1))
            }
            res =
                (nextResSlot >> (256 - offset * 8)) +
                (resSlot << (offset * 8));
        }
    }

    /** @notice Reads bytes32 from the stream
     * @param stream stream
     */
    function readBytes32(uint256 stream) internal returns (bytes32 res) {
        // assembly {
        //     let pos := mload(stream)
        //     pos := add(pos, 32)
        //     res := mload(pos)
        //     mstore(stream, pos)
        // }
        uint8 offset;
        uint8 slotNo;
        bytes32 resSlot;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 32)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        if (offset == 0) {
            // Zero offset checked as bytes32 is 32 bytes, so whole word size
            res = resSlot;
        } else {
            bytes32 nextResSlot;
            assembly {
                nextResSlot := sload(add(slotNo, 1))
            }
            res =
                (nextResSlot >> (256 - offset * 8)) ^
                (resSlot << (offset * 8));
        }
    }

    /** @notice Reads address from the stream
     * @param stream stream
     */
    function readAddress(uint256 stream) internal returns (address res) {
        // assembly {
        //     let pos := mload(stream)
        //     pos := add(pos, 20)
        //     res := mload(pos)
        //     mstore(stream, pos)
        // }
        uint8 offset;
        uint8 slotNo;
        uint256 resSlot;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 20)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        if (offset >= 20) {
            // 20 bytes checked as address is 20 bytes
            res = address(uint160(resSlot >> (256 - offset * 8)));
        } else {
            uint256 nextResSlot;
            assembly {
                nextResSlot := sload(add(slotNo, 1))
            }
            // res = uint32(resSlot >> offset) + uint32(nextResSlot << extra);
            res = address(
                uint160(
                    (nextResSlot >> (256 - offset * 8)) +
                        (resSlot << (offset * 8))
                )
            ); // not sure if add then cast or vice versa is better
        }
    }

    /** @notice Reads bytes from the stream
     * @param stream stream
     */
    function readBytes(uint256 stream) internal returns (bytes memory res) {
        // assembly {
        //     let pos := mload(stream)
        //     res := add(pos, 32)
        //     let length := mload(res)
        //     mstore(stream, add(res, length))
        // }
        uint8 offset;
        uint8 slotNo;
        uint256 resSlot;
        uint256 resLength;

        assembly {
            let pos := sload(stream)
            slotNo := div(pos, 0x20) // assuming it always rounds down - positive only
            pos := add(pos, 32)
            offset := mod(pos, 0x20)
            resSlot := sload(slotNo)
            sstore(stream, pos)
        }
        if (offset == 0) {
            // Zero offset checked as uint256 is 32 bytes, so whole word size
            resLength = resSlot;
            assembly {
                let pos := sload(stream)
                pos := add(pos, resLength)
                sstore(stream, pos)
            }
        } else {
            uint256 nextResSlot;
            uint8 bitOffset = offset * 8;
            assembly {
                nextResSlot := sload(add(slotNo, 1))
            }
            resLength =
                (nextResSlot >> (256 - bitOffset)) +
                (resSlot << (bitOffset));
            bytes memory startingBytes = new bytes(
                resLength > 32 - offset ? 32 - offset : resLength
            );
            assembly {
                let pos := sload(stream)
                pos := add(pos, resLength)
                sstore(stream, pos)
                mstore(add(startingBytes, 32), shl(bitOffset, nextResSlot))
            }
            res = bytes.concat(res, startingBytes);
            resLength -= (32 - offset);
            slotNo++;
        }
        uint256 steps = resLength / 32;
        bytes32 currentSlot;
        for (uint8 i = 0; i < steps; ++i) {
            slotNo++;
            assembly {
                currentSlot := sload(slotNo)
            }
            res = bytes.concat(res, currentSlot);
        }
        uint8 remainder = uint8(resLength % 32);
        if (remainder > 0) {
            slotNo++;
            bytes memory remainingBytes = new bytes(remainder);
            assembly {
                mstore(add(remainingBytes, 32), sload(slotNo))
            }
            res = bytes.concat(res, remainingBytes);
        }
    }

    /** @notice Deletes stream to allow gas refund
     * @param stream stream
     */
    function deleteStream(uint256 stream) internal {
        uint256 length;

        assembly {
            length := sload(add(stream, 1))
        }
        uint steps = (length % 32 != 0 ? length / 32 + 1 : length / 32) + 2; // rounding up
        for (uint8 i = 0; i < steps; ++i) {
            // Clear all stream data in storage
            assembly {
                sstore(add(stream, i), 0)
            }
        }
    }
}
