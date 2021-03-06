----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    00:43:00 04/17/2013 
-- Design Name: 
-- Module Name:    top - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.types.all;

entity top is
	Port(CLK      : in  STD_LOGIC;
		 RST      : in  STD_LOGIC;
		 TXD      : out STD_LOGIC;
		 RXD      : in  STD_LOGIC;
		 LEDS     : out STD_LOGIC_VECTOR(7 downto 0);
		 SW       : in  STD_LOGIC_VECTOR(3 downto 0);
		 CONT     : in  STD_LOGIC;
		 CONT_NET : in  STD_LOGIC);
end top;

architecture Behavioral of top is
	--type mainState is (stIdle, stPlayer, stPlayer2, stOurMove,  stWriteDown);
	type mainState is (stInit, stIdle, stFindFirstMove, stWriteFirstMove, stWriteFirstMoveAck, stWriteFirstComputerAck, stWriteOpponentMove, stWriteOpponentMoveAck, stWriteSecondOpponentMove, stWriteSecondOpponentMoveAck, stFindAMove, stWriteAMove, stWriteAMoveAck, stWriteComputerAck); --

	--	signal clk    : std_logic;
	signal locked   : std_logic;
	signal dcm_rst  : std_logic;
	signal slow_clk : std_logic;
	signal fast_clk : std_logic;
	signal clk_cnt  : integer := 0;

	signal stCur  : mainState := stInit;
	signal stNext : mainState;

	-- signals from blokus
	signal sig_write_ready         : std_logic;
	signal sig_best_move           : move;
	signal sig_move_generator_done : std_logic;

	-- signals to blokus
	signal sig_blokus_rst : std_logic := '1';
	signal sig_our_move   : std_logic;
	signal sig_cmd1       : move;
	signal sig_cmd2       : move;
	signal sig_write      : std_logic := '0';
	signal sig_player     : std_logic := '0';
	signal cmd_command    : move;

	-- signals to serial port
	signal sig_net_move_in : std_logic_vector(31 downto 0);
	signal sig_serial_send : std_logic;

	-- signals from serial port
	signal sig_big_reset       : std_logic;
	signal sig_opp_move        : std_logic_vector(31 downto 0);
	signal sig_opp_move2       : std_logic_vector(31 downto 0);
	signal sig_big_recv        : std_logic;
	signal sig_small_recv      : std_logic;
	signal sig_our_move_serial : std_logic;
	signal sig_flip_board      : std_logic;

	-- debug signals
	signal sig_state_debug : std_logic_vector(7 downto 0) := x"00";

begin
	dcm_rst <= RST or not locked;

	dcm : entity work.dcm_blokus
		port map(CLKIN_IN        => CLK,
			     RST_IN          => RST,
			     CLKDV_OUT       => slow_clk,
			     CLKIN_IBUFG_OUT => fast_clk,
			     CLK0_OUT        => open,
			     LOCKED_OUT      => locked);

	cmdHtoA : entity work.cmd_hex_to_ascii
		port map(
			hex_command   => sig_best_move,
			flip_board    => sig_flip_board,
			ascii_command => sig_net_move_in
		);

	cmdAtoH : entity work.cmd_ascii_to_hex
		port map(
			ascii_command       => sig_opp_move,
			flip_board          => sig_flip_board,
			hex_command_flipped => sig_cmd1
		);

	cmdAtoH2 : entity work.cmd_ascii_to_hex
		port map(
			ascii_command       => sig_opp_move2,
			flip_board          => sig_flip_board,
			hex_command_flipped => sig_cmd2
		);

	blokus : entity work.blokus
		PORT MAP(
			reset                   => sig_blokus_rst,
			clk                     => slow_clk,
			cmd_command             => cmd_command,
			sig_write               => sig_write,
			sig_player              => sig_player,
			sig_write_ready         => sig_write_ready,
			CONT                    => CONT,
			LEDS                    => LEDS, --sig_fake_leds, --
			SW                      => SW,
			sig_our_move            => sig_our_move,
			sig_best_move           => sig_best_move,
			sig_state_debug         => sig_state_debug,
			sig_move_generator_done => sig_move_generator_done
		);

	DataCntrl : entity work.DataCntrl
		port map(
			txd           => txd,
			rxd           => rxd,
			clk           => slow_clk,
			rst           => rst,
			net_move_in   => sig_net_move_in,
			net_big_reset => sig_big_reset,
			net_cmd_out   => sig_opp_move,
			net_cmd_out_2 => sig_opp_move2,
			big_recv      => sig_big_recv,
			small_recv    => sig_small_recv,
			our_move      => sig_our_move_serial,
			do_send_move  => sig_serial_send,
			flip_board    => sig_flip_board);

	process(slow_clk, dcm_rst)
	begin
		if (slow_clk = '1' and slow_clk'Event) then
			if dcm_rst = '1' or sig_big_reset = '1' then
				stCur <= stInit;
			else
				clk_cnt <= clk_cnt + 1;
				--				sig_clk_half <= not sig_clk_half;
				--				if sig_clk_half = '1' then
				if clk_cnt = 8 then
					stCur   <= stNext;
					--					sig_write_d <= sig_write;
					clk_cnt <= 0;
				end if;
			--				end if;
			end if;
		end if;
	end process;

	process(stCur, sig_our_move_serial, sig_big_recv, sig_small_recv, sig_write_ready, sig_best_move, sig_move_generator_done, sig_cmd1, sig_opp_move2, sig_cmd2)
	begin
		sig_write            <= '0';
		sig_our_move         <= '0';
		sig_blokus_rst       <= '0';
		sig_player           <= '0';
		cmd_command.x        <= (others => '0');
		cmd_command.y        <= (others => '0');
		cmd_command.name     <= (others => '0');
		cmd_command.rotation <= (others => '0');
		stNext               <= stCur;
		sig_state_debug      <= x"00";
		sig_serial_send      <= '0';

		case stCur is
			when stInit =>
				sig_state_debug <= x"01";
				sig_blokus_rst  <= '1';
				stNext          <= stIdle;

			when stIdle =>
				sig_state_debug <= x"02";

				if sig_our_move_serial = '1' then
					stNext <= stFindFirstMove;
				--					 else
				--						stNext <= stIdle;
				end if;

			when stFindFirstMove =>
				sig_our_move    <= '1';
				sig_state_debug <= x"03";

				if sig_move_generator_done = '1' and sig_write_ready = '1' then --or times up
					stNext <= stWriteFirstMove;
				--					 else 
				--						stNext <= stFindFirstMove;
				end if;

			when stWriteFirstMove =>    -- add new signal sig_host_state
				sig_state_debug <= x"04";

				--				sig_our_move    <= '1';

				sig_write   <= '1';
				--				sig_player  	 <= '0';
				cmd_command <= sig_best_move;

				if sig_write_ready = '0' then
					stNext <= stWriteFirstComputerAck; --stWriteFirstMoveAck;--
				end if;

			when stWriteFirstComputerAck =>
				sig_state_debug <= x"1c";
				sig_serial_send <= '1';
				--				sig_our_move    <= '1';
				--				cmd_command <= sig_best_move;

				if sig_our_move_serial = '0' then
					stNext <= stWriteFirstMoveAck;
				end if;

			when stWriteFirstMoveAck =>
				sig_state_debug <= sig_write_ready & "000" & x"5";
				--				sig_serial_send <= '1';
				--				sig_our_move    <= '1';

				if sig_write_ready = '1' and sig_our_move_serial = '1' then -- when 4XXXXYYYY
					if sig_big_recv = '1' then
						stNext <= stWriteSecondOpponentMove;
					elsif sig_small_recv = '1' then --when 3XXXX
						stNext <= stWriteOpponentMove;
					--						elsif sig_host_state = "010" then --when 2A or 25
					--							if sig_send_done = '1' then
					--								stNext <= stIdle;
					--							end if;
					end if;
				end if;

			when stWriteSecondOpponentMove =>
				sig_state_debug <= x"06";

				sig_player  <= '1';
				sig_write   <= '1';
				cmd_command <= sig_cmd2;

				if sig_write_ready = '0' then
					stNext <= stWriteSecondOpponentMoveAck;
				end if;

			when stWriteSecondOpponentMoveAck =>
				sig_state_debug <= x"07";
				sig_player      <= '1';
				--				cmd_command <= sig_cmd2;

				if sig_write_ready = '1' then
					stNext <= stWriteOpponentMove;
				end if;

			when stWriteOpponentMove =>
				sig_state_debug <= x"08";

				sig_player  <= '1';
				sig_write   <= '1';
				cmd_command <= sig_cmd1;
				if sig_write_ready = '0' then
					stNext <= stWriteOpponentMoveAck;
				end if;

			when stWriteOpponentMoveAck =>
				sig_state_debug <= x"09";
				sig_player      <= '1';
				if sig_write_ready = '1' then
					stNext <= stFindAMove;
				end if;

			when stFindAMove =>
				sig_state_debug <= x"0a";

				sig_our_move <= '1';
				--sig_player <= '0';
				if sig_move_generator_done = '1' then -- or timeout
					stNext <= stWriteAMove;
				end if;

			when stWriteAMove =>
				sig_state_debug <= x"0b";

				sig_player  <= '0';
				sig_write   <= '1';
				cmd_command <= sig_best_move;

				if sig_write_ready = '0' then
					stNext <= stWriteComputerAck;
				end if;

			when stWriteComputerAck =>
				sig_state_debug <= x"0c";
				sig_serial_send <= '1';
				if sig_our_move_serial = '0' then
					stNext <= stWriteAMoveAck;
				end if;

			when stWriteAMoveAck =>
				sig_state_debug <= x"0d";

				if sig_write_ready = '1' and sig_our_move_serial = '1' then
					stNext <= stWriteOpponentMove;
				end if;

		end case;

	end process;

end Behavioral;

