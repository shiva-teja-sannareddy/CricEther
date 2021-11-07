//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

//ABIEncoderV2 allows to use struct as function parameters

contract CricEther {
    // To store current state of match
    enum MatchState {
        Upcoming,
        Live,
        Win,
        Draw
    }

    // To store Team choices of players in, and refer winner.
    enum Team {
        Team1,
        Team2
    }

    // Struct to store data of each match. A match can only be added by Admin.
    struct Match {
        uint256 matchId;        // Unique Match ID. Starting from 1, will be incremented for every new match added.
        string team1;           // Team 1 name.
        string team2;           // Team 2 name.
        MatchState state;       // Enum to store match state.
        Team winner;            // Enum to store winning Team, This should only be assigned if the match state is set to Win.
        uint256 totalBets;      // To track total number of bets posted for this match. This will also be used to generate Unique bet ID.
    }

    // Struct to store bet placed on each match. A bet can only be posted by user. Each match can have multiple bets posted by users.
    struct Bet {
        uint256 matchId;                // Unique Match ID. This match ID should be valid i.e., created by Admin.
        uint256 betId;                  // Unique Bet ID. Starting from 1, will be incremented for every new bet posted by users for the above match ID.
        address payable postedBy;       // Address of the account using which the bet was posted -> Player 1.
        Team[2] playerTeamChoice;       // Enum of team choice, index 0 -> Choice of player who posted the bet, index 1 -> choice of player who accepted the bet.
        uint256 player1Entry;           // Entry fees of player 1.
        uint256 ratio;                  // Ratio -> player1Entry : player2Entry
        uint256 player2Entry;           // Entry fees of player 2.
        bool accepted;                  // Boolean to check whether the bet was accepted by any player.
        address payable acceptedBy;     // Address of the account using which the bet was accepted -> Player 2.
        bool isTransferred;             // Boolean to check whether the money was transferred to winner.
    }

    address payable public admin;   // Address of admin to restrict admin features.
    uint256 matchNo;                // To track total number of matches and assign match ID to each match.
    uint256 commission;             // 1% of prize money is charged as commission fee.

    mapping(uint256 => Match) public matches;                   // Mapping which maps Match ID to Match structs.
    mapping(uint256 => mapping(uint256 => Bet)) public bets;    // Nested Mapping which maps (Match ID) => (Bet ID) => (Bet struct).
    uint256[] public upcomingMatches;                           // Array which stores match IDs of Upcoming matches.
    uint256[] public liveMatches;                               // Array which stores match IDs of Live matches

    // Events
    event matchAdded(Match);
    event betAdded(Bet);
    event betAccepted(Bet);
    event matchLive(Match);
    event matchDeclared(Match);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier notAdmin() {
        require(msg.sender != admin);
        _;
    }

    // Constructor
    constructor() {
        admin = payable(msg.sender);
        matchNo = 0;
    }

    // To check the user account is Admin account or not.
    function isAdmin() public view returns (bool) {
        if (msg.sender == admin) return true;
        else return false;
    }

    // Admin adds a new match on which users can post bets. The match state is set to Upcoming bby default which can be changed to Live using setLive() function.
    function addmatch(string memory _team1, string memory _team2)
        public
        onlyAdmin
    {
        matchNo++;
        Match memory _match;
        _match.matchId = matchNo;
        _match.team1 = _team1;
        _match.team2 = _team2;
        _match.state = MatchState.Upcoming;
        _match.totalBets = 0;
        matches[matchNo] = _match;      // Add to matches mapping.
        upcomingMatches.push(matchNo);  // Add match ID to upcoming matches.
        emit matchAdded(_match);
    }

    // To get details for a particular match using match ID.
    function getMatch(uint256 _matchId) public view returns (Match memory) {
        require(matches[_matchId].matchId == _matchId, "Invalid match");
        return matches[_matchId];
    }

    // To get details of all Upcoming matches.
    function getUpcomingMatches() public view returns (Match[] memory) {
        Match[] memory _matches = new Match[](upcomingMatches.length);
        uint256 i;
        for (i = 0; i < upcomingMatches.length; i++) {
            _matches[i] = matches[upcomingMatches[i]];
        }
        return _matches;
    }

    // To get details of all Live matches.
    function getLiveMatches() public view returns (Match[] memory) {
        Match[] memory _matches = new Match[](liveMatches.length);
        for (uint256 i = 0; i < liveMatches.length; i++) {
            _matches[i] = matches[liveMatches[i]];
        }
        return _matches;
    }

    // A user can post a Bet, Another user can accept this Bet to complete a trade.
    // A payable function where the player who posts the bet has to send money equal to the entry fee mentioned at the front end.
    //_team is received as 0 or 1, #0 -> Team 1,  #1 -> Team 2
    function postBet(
        uint256 _matchId,
        uint256 _player1Entry,
        uint256 _ratio,
        uint256 _player2Entry,
        uint256 _team
    ) public payable notAdmin {
        require(matches[_matchId].matchId == _matchId, "Invalid match");
        require(
            _player1Entry == msg.value,
            "Bet Value sent not equal to entry fees"
        );
        require(_team == 0 || _team == 1, "Invalid Team");
        Bet memory _bet;
        matches[_matchId].totalBets++;
        _bet.matchId = _matchId;
        _bet.betId = matches[_matchId].totalBets;
        _bet.postedBy = payable(msg.sender);
        _bet.playerTeamChoice[0] = Team(_team);
        _bet.player1Entry = msg.value;
        _bet.ratio = _ratio;
        _bet.player2Entry = _player2Entry;
        bets[_matchId][matches[_matchId].totalBets] = _bet; // Add to bets mapping using Match ID and Bet ID i.e., (Match ID) => (Bet ID) => (Bet struct).
        emit betAdded(_bet);
    }

    // To fetch all bets posted for a particular Match. This can be used to display on front end for users.
    // The bets that are already accepted will not be returned.
    function getBets(uint256 _matchId)
        public
        view
        returns (Bet[] memory, uint256)
    {
        require(matches[_matchId].matchId == _matchId, "Invalid Match");
        Bet[] memory _bets = new Bet[](matches[_matchId].totalBets);
        uint256 _count = 0;
        for (uint256 i = 1; i <= matches[_matchId].totalBets; i++) {
            if (!bets[_matchId][i].accepted)
                _bets[_count++] = bets[_matchId][i];
        }
        return (_bets, _count);
    }

    // An user can accept an already posted bet, by checking the ratio and returns.
    // The user who posted a bet cannot accept his own bet.
    function acceptBet(
        uint256 _matchId,
        uint256 _betId,
        uint256 _team
    ) public payable notAdmin {
        require(matches[_matchId].matchId == _matchId, "Invalid match");
        require(bets[_matchId][_betId].betId == _betId, "Invalid Bet");
        require(
            bets[_matchId][_betId].postedBy != msg.sender,
            "You cannot accept your own bet"
        );
        require(
            bets[_matchId][_betId].playerTeamChoice[0] != Team(_team),
            "Opponent has chosen the Team"
        );
        require(
            bets[_matchId][_betId].player2Entry == msg.value,
            "Bet Value sent not equal to entry fees"
        );
        require(_team == 0 || _team == 1, "Invalid Team");
        bets[_matchId][_betId].playerTeamChoice[1] = Team(_team);
        bets[_matchId][_betId].acceptedBy = payable(msg.sender);
        bets[_matchId][_betId].accepted = true;

        emit betAccepted(bets[_matchId][_betId]);
    }

    // To set a match from Upcoming state to Live state.
    // Delete from Upcoming matches array and add to Live matches array.
    function setLive(uint256 _matchId) public onlyAdmin {
        require(matches[_matchId].matchId == _matchId, "Invalid match");
        matches[_matchId].state = MatchState.Live;
        liveMatches.push(_matchId);
        for (uint256 i = 0; i < upcomingMatches.length; i++) {
            if (upcomingMatches[i] == _matchId) {
                upcomingMatches[i] = upcomingMatches[
                    upcomingMatches.length - 1
                ];
                upcomingMatches.pop();
                break;
            }
        }
        deleteUpcomingMatch(_matchId);
        emit matchLive(matches[_matchId]);
    }

    // Admin ends and declares a Match's result i.e., Win or Draw.
    // The money is transferred to the winners by deducting 1% commission charge.
    // In case of draw or the bet was not accepted by another player, then the money is refunded.
    function endMatch(
        uint256 _matchId,
        bool isDraw,
        uint256 _winner
    ) public onlyAdmin {
        require(matches[_matchId].matchId == _matchId, "Invalid match");
        require(_winner == 0 || _winner == 1, "Invalid Team");
        uint256 _commission;
        uint256 _prizeMoney;
        if (isDraw) {
            matches[_matchId].state = MatchState.Draw;
        } else {
            matches[_matchId].state = MatchState.Win;
            if (_winner == 0) matches[_matchId].winner = Team.Team1;
            else matches[_matchId].winner = Team.Team2;
        }

        for (uint256 i = 1; i <= matches[_matchId].totalBets; i++) {
            Bet memory bet = bets[_matchId][i];
            address payable _winnerAddress;
            address payable p1 = bet.postedBy;
            address payable p2 = bet.acceptedBy;

            if (bet.accepted) {
                _prizeMoney = bet.player1Entry + bet.player2Entry;
                _commission = _prizeMoney / 100;
                _prizeMoney = _prizeMoney - _commission;
                if (isDraw) {
                    p1.transfer(bet.player1Entry);
                    p2.transfer(bet.player2Entry);
                } else {
                    if (matches[_matchId].winner == bet.playerTeamChoice[0]) {
                        _winnerAddress = bet.postedBy;
                    } else if (
                        matches[_matchId].winner == bet.playerTeamChoice[1]
                    ) {
                        _winnerAddress = bet.acceptedBy;
                    }
                    _winnerAddress.transfer(_prizeMoney);
                }
            } else {
                (bet.postedBy).transfer(bet.player1Entry);
            }

            bets[_matchId][i].isTransferred = true;
            commission += _commission;
        }
        emit matchDeclared(matches[_matchId]);
        delete matches[_matchId];
        deleteLiveMatch(_matchId);
    }

    // Delete a match form Live Matches array.
    function deleteLiveMatch(uint256 _matchId) internal {
        for (uint256 i = 0; i < liveMatches.length; i++) {
            if (liveMatches[i] == _matchId) {
                liveMatches[i] = liveMatches[liveMatches.length - 1];
                liveMatches.pop();
                break;
            }
        }
    }

    // Delete a match from Upcoming Matches array.
    function deleteUpcomingMatch(uint256 _matchId) internal {
        for (uint256 i = 0; i < upcomingMatches.length; i++) {
            if (upcomingMatches[i] == _matchId) {
                upcomingMatches[i] = upcomingMatches[
                    upcomingMatches.length - 1
                ];
                upcomingMatches.pop();
                break;
            }
        }
    }

    // To withdraw the commission earned to the Admin Account.
    function adminWithdrawCommission() public payable onlyAdmin {
        uint256 _commission = commission;
        commission = 0;
        admin.transfer(_commission);
    }

    // To fetch the amount of commission earned.
    function getCommission() public view onlyAdmin returns (uint256) {
        return commission;
    }

    // To fetch the Balance of the contract.
    function getBalance() public view onlyAdmin returns (uint256) {
        return address(this).balance;
    }
}
