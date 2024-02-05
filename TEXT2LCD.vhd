 LIBRARY IEEE;
 USE IEEE.std_logic_1164.all;
 use ieee.numeric_std.all;
 use ieee.math_real.all;

 ENTITY TEXT2LCD IS
 GENERIC(
    G_CLK_FREQ           : real      := 90.0;
    
    G_POWER_UP_WAIT : real := 50000.0; -- µs
    
    G_INIT_WAIT1 : real := 4100.0; -- µs
    G_INIT_WAIT2 : real := 4100.0; -- µs
    G_INIT_WAIT3 : real := 4100.0; -- µs

    G_INSTRUCTION_WAIT : real := 2000.0

 );
 PORT(
    I_CLOCK : IN STD_LOGIC;
    I_RESET_N : IN STD_LOGIC;
    I_LINE1 : IN string (1 to 16);
    I_LINE2 : IN string (1 to 16); 
    O_RW : OUT STD_LOGIC;
    O_RS : OUT STD_LOGIC;
    O_EN : OUT STD_LOGIC;
    O_DATA : OUT STD_LOGIC_VECTOR(7 downto 0)
 );
 END TEXT2LCD;

 ARCHITECTURE ARCH OF TEXT2LCD IS


constant c_clock_period : real := 1.0 / G_CLK_FREQ * 1000.0;

constant c_power_up_wait : natural := natural(ceil(G_POWER_UP_WAIT * 1000.0 / c_clock_period));
constant c_init_wait1 : natural := natural(ceil(G_INIT_WAIT1 * 1000.0 / c_clock_period));
constant c_init_wait2 : natural := c_init_wait1 + natural(ceil(G_INIT_WAIT2 * 1000.0 / c_clock_period));
constant c_init_wait3 : natural := c_init_wait2 + natural(ceil(G_INIT_WAIT3 * 1000.0 / c_clock_period));

constant c_instruction_wait_base : natural := natural(ceil(G_INSTRUCTION_WAIT * 250.0 / c_clock_period));
constant c_instruction_wait1 : natural := natural(c_instruction_wait_base);
constant c_instruction_wait2 : natural := natural(c_instruction_wait_base * 2);
constant c_instruction_wait3 : natural := natural(c_instruction_wait_base * 3);
constant c_instruction_wait4 : natural := natural(c_instruction_wait_base * 4);

type character_slv is array (character) of std_logic_vector(7 downto 0);

constant c_character_lut : character_slv := (
    '0' => "00110000",
    '1' => "00110001",
    '2' => "00110010",
    '3' => "00110011",
    '4' => "00110100",
    '5' => "00110101",
    '6' => "00110110",
    '7' => "00110111",
    '8' => "00111000",
    '9' => "00111001",
    'A' => "01000001",
    'B' => "01000010",
    'C' => "01000011",
    'D' => "01000100",
    'E' => "01000101",
    'F' => "01000110",
    'G' => "01000111",
    'H' => "01001000",
    'I' => "01001001",
    'J' => "01001010",
    'K' => "01001011",
    'L' => "01001100",
    'M' => "01001101",
    'N' => "01001110",
    'O' => "01001111",
    'P' => "01010000",
    'Q' => "01010001",
    'R' => "01010010",
    'S' => "01010011",
    'T' => "01010100",
    'U' => "01010101",
    'V' => "01010110",
    'W' => "01010111",
    'X' => "01011000",
    'Y' => "01011001",
    'Z' => "01011010",
    'a' => "01100001",
    'b' => "01100010",
    'c' => "01100011",
    'd' => "01100100",
    'e' => "01100101",
    'f' => "01100110",
    'g' => "01100111",
    'h' => "01101000",
    'i' => "01101001",
    'j' => "01101010",
    'k' => "01101011",
    'l' => "01101100",
    'm' => "01101101",
    'n' => "01101110",
    'o' => "01101111",
    'p' => "01110000",
    'q' => "01110001",
    'r' => "01110010",
    's' => "01110011",
    't' => "01110100",
    'u' => "01110101",
    'v' => "01110110",
    'w' => "01110111",
    'x' => "01111000",
    'y' => "01111001",
    'z' => "01111010",
    ' ' => "00100000",  -- Space
    others => "00000000"
);

type lcd_line is array (15 downto 0) of std_logic_vector(7 downto 0);
signal r_line1 : lcd_line;
signal r_line2 : lcd_line;

 type t_states is (POWER_UP, CONFIG, RESET_LINE, TRANSMIT_LINE1, TRANSMIT_LINE2);
 signal r_current_state : t_states;
 signal w_next_state : t_states;

 signal r_data : STD_LOGIC_VECTOR(7 downto 0);
 signal r_rs : std_logic;
 signal r_rw : std_logic;
 signal r_en : std_logic;

 signal r_state_count : integer range 0 to 9999999;

 signal r_next_line : integer range 1 to 2;
 signal r_current_character : integer range 0 to 15;

 function string_to_slv_array(inputString: string) return lcd_line is
    variable result : lcd_line;
 BEGIN

    for i in 0 to 15 loop
        result(i) := c_character_lut(inputString(i + 1));
    end loop;

        return result;

 end string_to_slv_array;

begin

async : process (r_current_state, r_state_count)
    
begin

    case (r_current_state) is
        when POWER_UP =>
            if(r_state_count = c_power_up_wait) then
                w_next_state <= CONFIG;
            else
                w_next_state <= POWER_UP;
            end if;

        when CONFIG => 
            if(r_state_count = c_init_wait3) then
                w_next_state <= TRANSMIT_LINE1;
            else
                w_next_state <= CONFIG;
            end if;

        when RESET_LINE =>
        if(r_state_count = c_instruction_wait4) then
            if(r_next_line = 1) then
                w_next_state <= TRANSMIT_LINE1;
                r_line1 <= string_to_slv_array(I_LINE1);
                r_line2 <= string_to_slv_array(I_LINE2);
            else
                w_next_state <= TRANSMIT_LINE2;
            end if;
        else 
            w_next_state <= RESET_LINE;
        end if;

        when TRANSMIT_LINE1 =>
            if(r_state_count = c_instruction_wait4) then
                if(r_current_character = 15) then
                    w_next_state <= RESET_LINE;
                else
                    w_next_state <= TRANSMIT_LINE1;
                end if;
            else 
                w_next_state <= TRANSMIT_LINE1;
            end if;

        when TRANSMIT_LINE2 =>
            if(r_state_count = c_instruction_wait4) then
                if(r_current_character = 15) then
                    w_next_state <= RESET_LINE;
                else
                    w_next_state <= TRANSMIT_LINE2;
                end if;
            else 
                w_next_state <= TRANSMIT_LINE2;
            end if;


end case;

end process;

sync : process(I_CLOCK, I_RESET_N)
begin

    if(I_RESET_N = '0') then

    elsif(rising_edge(I_CLOCK)) then
        if(w_next_state /= r_current_state) then
            r_state_count <= 0;
        else
            r_state_count <= r_state_count + 1;
        end if;

    r_current_state <= w_next_state;
    -- r_current_character <= 0;

    case (r_current_state) is
        when POWER_UP =>
            r_data <= (others => '0');

            if(w_next_state = CONFIG) then 
                r_state_count <= 0;
            end if;

        when CONFIG => 
            if(r_state_count < c_init_wait1) then
                r_data <= "00111100";
            elsif(r_state_count < c_init_wait2) then
                r_data <= "00000000";
            else
                r_data <= "00000110";
            end if;

            if (w_next_state = TRANSMIT_LINE1) then 
                r_state_count <= 0;
            end if;

        when RESET_LINE =>
            if(r_state_count < c_instruction_wait1) then
                r_en <= '0';
            elsif (r_state_count < c_instruction_wait2) then
                r_en <= '1';
            else
                r_en <= '0';
            end if;

            if(r_state_count = 0) then
                if(r_next_line = 1) then
                    r_data <= "11000000";
                    r_next_line <= 2;
                else
                    r_data <= "10000000";
                    r_next_line <= 1;
                end if;
            end if;

            r_current_character <= 0;
            r_rs <= '0';
            r_rw <= '0';

            if(r_state_count = c_instruction_wait4) then
                r_state_count <= 0;
            end if;


        when TRANSMIT_LINE1 =>
            if(r_state_count < c_instruction_wait1) then
                r_en <= '0';
            elsif (r_state_count < c_instruction_wait2) then
                r_en <= '1';
            else
                r_en <= '0';
            end if;

            r_next_line <= 1;
            r_rs <= '1';
            r_rw <= '0';
            r_data <= r_line1(r_current_character);

            if(r_state_count = c_instruction_wait4) then
                if(r_current_character < 15) then
                    r_current_character <= r_current_character + 1;
                else
                    r_current_character <= 0;
                end if;

                r_state_count <= 0;
            end if;

        when TRANSMIT_LINE2 =>
            if(r_state_count < c_instruction_wait1) then
                r_en <= '0';
            elsif (r_state_count < c_instruction_wait2) then
                r_en <= '1';
            else
                r_en <= '0';
            end if;

            r_next_line <= 2;
            r_rs <= '1';
            r_rw <= '0';
            r_data <= r_line2(r_current_character);

            if(r_state_count = c_instruction_wait4) then
                if(r_current_character < 15) then
                    r_current_character <= r_current_character + 1;
                else
                    r_current_character <= 0;
                end if;

                r_state_count <= 0;
            end if;

    end case;

end if;
end process;

O_RS <= r_rs;
O_EN <= r_en;
O_RW <= r_rw;
O_DATA <= r_data;

 END ARCHITECTURE;