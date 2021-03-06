----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:41:27 04/10/2013 
-- Design Name: 
-- Module Name:    piece_bitmap_marker - Behavioral 
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

use work.types.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity piece_bitmap_marker is
	Port(piece_bitmap            : in  std_logic_vector(24 downto 0);
		 player                  : in  std_logic;
		 piece_bitmap_marker_us  : out board_window_7;
		 piece_bitmap_marker_opp : out board_window_7);
end piece_bitmap_marker;

architecture Behavioral of piece_bitmap_marker is
	type matrix is array (0 to 6, 0 to 6) of std_logic;
	signal sig_piece_bitmap_dump : matrix := (others => (others => '0'));

begin
	copy : process(piece_bitmap) is
	begin
		for x in 0 to 6 loop
			for y in 0 to 6 loop
				if x = 0 or x = 6 or y = 0 or y = 6 then
					sig_piece_bitmap_dump(y, x) <= '0';
				else
					sig_piece_bitmap_dump(y, x) <= piece_bitmap(24 - ((x - 1) + (5 * (y - 1))));
				end if;
			end loop;
		end loop;
	end process;

	marker : process(sig_piece_bitmap_dump, player) is
	begin
		for x in 0 to 6 loop
			for y in 0 to 6 loop
				if sig_piece_bitmap_dump(y, x) = '0' then
					--check edge
					if (y - 1 >= 0 and sig_piece_bitmap_dump(y - 1, x) = '1') or (x - 1 >= 0 and sig_piece_bitmap_dump(y, x - 1) = '1') or (y + 1 <= 6 and sig_piece_bitmap_dump(y + 1, x) = '1') or (x + 1 <= 6 and sig_piece_bitmap_dump(y, x + 1) = '1') then
						if player = '0' then
							piece_bitmap_marker_us(y, x)  <= OCCUPI;
							piece_bitmap_marker_opp(y, x) <= EMPTY;
						else
							piece_bitmap_marker_opp(y, x) <= OCCUPI;
							piece_bitmap_marker_us(y, x)  <= EMPTY;
						end if;
					-- check corner
					elsif (x - 1 >= 0 and y - 1 >= 0 and sig_piece_bitmap_dump(y - 1, x - 1) = '1') or (x - 1 >= 0 and y + 1 <= 6 and sig_piece_bitmap_dump(y + 1, x - 1) = '1') or (x + 1 <= 6 and y + 1 <= 6 and sig_piece_bitmap_dump(y + 1, x + 1) = '1') or (x + 1 <= 6 and y - 1 >= 0 and
						sig_piece_bitmap_dump(y - 1, x + 1) = '1') then
						if player = '0' then
							piece_bitmap_marker_us(y, x)  <= ACTIVE;
							piece_bitmap_marker_opp(y, x) <= EMPTY;
						else
							piece_bitmap_marker_opp(y, x) <= ACTIVE;
							piece_bitmap_marker_us(y, x)  <= EMPTY;
						end if;
					-- if not edge and not corner
					else
						piece_bitmap_marker_us(y, x)  <= EMPTY;
						piece_bitmap_marker_opp(y, x) <= EMPTY;
					end if;
				else
					piece_bitmap_marker_us(y, x)  <= OCCUPI;
					piece_bitmap_marker_opp(y, x) <= OCCUPI;
				end if;
			end loop;
		end loop;
	end process;

end Behavioral;

