// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FHE, ebool, euint8, euint64, externalEuint8} from "@fhevm/solidity/lib/FHE.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";

/**
 * @title SecretColorVote
 * @notice Тайное голосование:
 *  - Вход: зашифрованный выбор категории (euint8)
 *  - Обновление: counts[i] += 1 для выбранной категории, без раскрытия выбора
 *  - Финализация: делаем гистограмму публично дешифруемой (publicDecrypt), индивидуальных голосов нет
 */
contract SecretColorVote is SepoliaConfig {
    /* ─── Ownable ─────────────────────────────────────────────────────────── */
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint8 numCategories_) {
        require(numCategories_ > 0, "No categories");
        owner = msg.sender;

        // инициализируем шифрованные счётчики нулями и даём контракту право их переиспользовать
        _counts = new euint64[](numCategories_);
        for (uint8 i = 0; i < numCategories_; i++) {
            _counts[i] = FHE.asEuint64(0);
            FHE.allowThis(_counts[i]);
        }
        _votingOpen = true;
    }

    function transferOwnership(address n) external onlyOwner {
        require(n != address(0), "Zero owner");
        owner = n;
    }

    function version() external pure returns (string memory) {
        return "SecretColorVote/1.0.0-sepolia";
    }

    /* ─── Storage ─────────────────────────────────────────────────────────── */
    euint64[] private _counts; // зашифрованные счётчики по категориям
    bool private _votingOpen; // идёт ли голосование
    bool private _published; // опубликована ли гистограмма
    mapping(address => bool) public hasVoted; // один голос на адрес (раскрывает факт участия, но не выбор)

    /* ─── Events ──────────────────────────────────────────────────────────── */
    event Voted(address indexed voter);
    event VotingClosed(address indexed by);
    event HistogramPublished(uint8 indexed category, bytes32 handle);
    event AllHandles(bytes32[] handles); // удобно фронту получить все хэндлы разом из логов

    /* ─── Public info (без FHE-арифметики) ───────────────────────────────── */
    function categoriesCount() external view returns (uint8) {
        return uint8(_counts.length);
    }

    function votingOpen() external view returns (bool) {
        return _votingOpen;
    }

    function histogramPublished() external view returns (bool) {
        return _published;
    }

    /* ─── Голосование ─────────────────────────────────────────────────────── */
    /**
     * @param choiceExt зашифрованная категория (0..N-1) как externalEuint8
     * @param proof     attestation от SDK (bytes)
     *
     * Инкрементит лишь выбранную категорию, используя ebool-сравнения и FHE.select,
     * без раскрытия выбора. Повторное голосование запрещено.
     */
    function vote(externalEuint8 choiceExt, bytes calldata proof) external {
        require(_votingOpen, "Voting closed");
        require(!hasVoted[msg.sender], "Already voted");
        require(proof.length > 0, "Empty proof");

        euint8 choice = FHE.fromExternal(choiceExt, proof);

        // Для каждой категории: if (choice == i) counts[i] += 1; иначе без изменений.
        uint8 n = uint8(_counts.length);
        for (uint8 i = 0; i < n; i++) {
            ebool isThis = FHE.eq(choice, FHE.asEuint8(i));
            euint64 addOne = FHE.select(isThis, FHE.asEuint64(1), FHE.asEuint64(0));
            _counts[i] = FHE.add(_counts[i], addOne);

            // Разрешаем контракту переиспользовать обновлённые шифротексты в следующих tx
            FHE.allowThis(_counts[i]);
        }

        hasVoted[msg.sender] = true;
        emit Voted(msg.sender);
    }

    /* ─── Админские действия ──────────────────────────────────────────────── */
    function closeVoting() external onlyOwner {
        require(_votingOpen, "Already closed");
        _votingOpen = false;
        emit VotingClosed(msg.sender);
    }

    /**
     * Публикует гистограмму: делает каждый счётчик публично дешифруемым.
     * Индивидуальные голоса нигде не хранятся и не раскрываются.
     */
    function publishHistogram() external onlyOwner {
        require(!_votingOpen, "Close first");
        require(!_published, "Already published");

        uint8 n = uint8(_counts.length);
        bytes32[] memory handles = new bytes32[](n);

        for (uint8 i = 0; i < n; i++) {
            FHE.makePubliclyDecryptable(_counts[i]); // теперь relayer.publicDecrypt(handle) доступен всем
            handles[i] = FHE.toBytes32(_counts[i]); // хэндл публичного счётчика
            emit HistogramPublished(i, handles[i]);
        }

        _published = true;
        emit AllHandles(handles); // фронту удобно достать все handle одним событием
    }

    /* ─── Геттеры для фронта ──────────────────────────────────────────────── */
    // Возвращает bytes32-хэндлы для всех категорий (для relayer.publicDecrypt(handle)).
    function getHistogramHandles() external view returns (bytes32[] memory out) {
        uint8 n = uint8(_counts.length);
        out = new bytes32[](n);
        for (uint8 i = 0; i < n; i++) {
            out[i] = FHE.toBytes32(_counts[i]);
        }
    }
}
