// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/** @notice Simple read stream */
library InputStreamCustom {
    /** @notice Creates stream from data
     * @param data data
     */
    function createStream(
        bytes memory data
    ) internal pure returns (uint256 stream) {
        assembly {
            stream := mload(0x40)
            mstore(0x40, add(stream, 64))
            mstore(stream, data)
            let length := mload(data)
            mstore(add(stream, 32), add(data, length))
        }
    }

    /** @notice Checks if stream is not empty
     * @param stream stream
     */
    function isNotEmpty(uint256 stream) internal pure returns (bool) {
        uint256 pos;
        uint256 finish;
        assembly {
            pos := mload(stream)
            finish := mload(add(stream, 32))
        }
        return pos < finish;
    }

    /** @notice Reads uint8 from the stream
     * @param stream stream
     */
    function readUint8(uint256 stream) internal pure returns (uint8 res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 1)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads uint16 from the stream
     * @param stream stream
     */
    function readUint16(uint256 stream) internal pure returns (uint16 res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 2)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads uint24 from the stream
     * @param stream stream
     */
    function readUint24(uint256 stream) internal pure returns (uint24 res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 3)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads uint32 from the stream
     * @param stream stream
     */
    function readUint32(uint256 stream) internal pure returns (uint32 res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 4)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads uint64 from the stream
     * @param stream stream
     */
    function readUint64(uint256 stream) internal pure returns (uint64 res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 8)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads uint256 from the stream
     * @param stream stream
     */
    function readUint(uint256 stream) internal pure returns (uint256 res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 32)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads bytes32 from the stream
     * @param stream stream
     */
    function readBytes32(uint256 stream) internal pure returns (bytes32 res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 32)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads address from the stream
     * @param stream stream
     */
    function readAddress(uint256 stream) internal pure returns (address res) {
        assembly {
            let pos := mload(stream)
            pos := add(pos, 20)
            res := mload(pos)
            mstore(stream, pos)
        }
    }

    /** @notice Reads bytes from the stream
     * @param stream stream
     */
    function readBytes(
        uint256 stream
    ) internal pure returns (bytes memory res) {
        assembly {
            let pos := mload(stream)
            res := add(pos, 32)
            let length := mload(res)
            mstore(stream, add(res, length))
        }
    }

    /** @notice Returns bytes remining in stream, modifying original stream to create new bytes variable - old stream MIGHT still be usable not checked
     * @param stream stream
     */
    function cutStreamToBytesRemaining(
        uint256 stream
    ) internal pure returns (bytes memory route) {
        assembly {
            // let pos := mload(stream)
            route := mload(stream)
            let finish := mload(add(stream, 32))
            // let lengthRemaining := sub(finish, pos)
            // route := sub(pos, 32)
            let lengthRemaining := sub(finish, route)
            mstore(route, lengthRemaining)
        }
    }
}
