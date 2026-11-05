
`timescale 1 ns / 1 ps

	module audio_fx_coprocessor_axi_slave_lite_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here


		output wire [1:0] cfg_mode,
		output wire [15:0] cfg_delay_samples,
		output wire [7:0] cfg_feedback_q8,
		output wire [8:0] cfg_volume_q8,

		output wire audio_in_wr_pulse,
		output wire signed [15:0] audio_in_wr_data,
		output wire audio_in_wr_strb_ok,
		output wire audio_out_rd_pulse,
		output wire clear_error_pulse,

		input wire status_input_ready,
		input wire status_busy,
		input wire status_output_valid,
		input wire status_rejected_write,
		input wire signed [15:0] audio_out_data,



		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
		// privilege and security level of the transaction, and whether
		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave)
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
		// valid data. There is one write strobe bit for each eight
		// bits of the write data bus.
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
		// and security level of the transaction, and whether the
		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 2;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 8
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg7;
	integer	 byte_index;
	wire write_commit;
	wire [2:0] write_reg_index;
	wire read_commit;
	wire [2:0] read_reg_index;
	reg [C_S_AXI_DATA_WIDTH-1:0] read_data_mux;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;

	// State machine variables and encodings from the generated template.
	reg [1:0] state_write;
	reg [1:0] state_read;
	localparam Idle  = 2'b00,
	           Raddr = 2'b10,
	           Rdata = 2'b11,
	           Waddr = 2'b10,
	           Wdata = 2'b11;

	assign write_commit = S_AXI_WVALID && S_AXI_WREADY &&
		(((state_write == Waddr) && S_AXI_AWVALID && S_AXI_AWREADY) ||
		 (state_write == Wdata));
	assign write_reg_index = (S_AXI_AWVALID) ?
		S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] :
		axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
	assign read_commit = S_AXI_RVALID && S_AXI_RREADY;
	assign read_reg_index =
		axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
	// Implement Write state machine
	// Outstanding write transactions are not supported by the slave i.e., master should assert bready to receive response on or before it starts sending the new transaction
	always @(posedge S_AXI_ACLK)
	  begin
	     if (S_AXI_ARESETN == 1'b0)
	       begin
	         axi_awready <= 0;
	         axi_wready <= 0;
	         axi_bvalid <= 0;
	         axi_bresp <= 0;
	         axi_awaddr <= 0;
	         state_write <= Idle;
	       end
	     else
	       begin
	         case(state_write)
	           Idle:
	             begin
	               if(S_AXI_ARESETN == 1'b1)
	                 begin
	                   axi_awready <= 1'b1;
	                   axi_wready <= 1'b1;
	                   state_write <= Waddr;
	                 end
	               else state_write <= state_write;
	             end
	           Waddr:        //At this state, slave is ready to receive address along with corresponding control signals and first data packet. Response valid is also handled at this state
	             begin
	               if (S_AXI_AWVALID && S_AXI_AWREADY)
	                  begin
	                    axi_awaddr <= S_AXI_AWADDR;
	                    if(S_AXI_WVALID)
	                      begin
	                        axi_awready <= 1'b1;
	                        state_write <= Waddr;
	                        axi_bvalid <= 1'b1;
	                      end
	                    else
	                      begin
	                        axi_awready <= 1'b0;
	                        state_write <= Wdata;
	                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                      end
	                  end
	               else
	                  begin
	                    state_write <= state_write;
	                    if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                   end
	             end
	          Wdata:        //At this state, slave is ready to receive the data packets until the number of transfers is equal to burst length
	             begin
	               if (S_AXI_WVALID)
	                 begin
	                   state_write <= Waddr;
	                   axi_bvalid <= 1'b1;
	                   axi_awready <= 1'b1;
	                 end
	                else
	                 begin
	                   state_write <= state_write;
	                   if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                 end
	             end
	          endcase
	        end
	      end

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.


	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	      slv_reg4 <= 0;
	      slv_reg5 <= 0;
	      slv_reg6 <= 32'd256; // Volume maximo no reset
	      slv_reg7 <= 0;
	    end
	  else if (write_commit)
	    begin
	      case (write_reg_index)
	        3'h0:
	          for (byte_index = 0;
	               byte_index <= (C_S_AXI_DATA_WIDTH/8)-1;
	               byte_index = byte_index+1)
	            if (S_AXI_WSTRB[byte_index] == 1'b1)
	              slv_reg0[(byte_index*8) +: 8] <=
	                S_AXI_WDATA[(byte_index*8) +: 8];
	        3'h4:
	          for (byte_index = 0;
	               byte_index <= (C_S_AXI_DATA_WIDTH/8)-1;
	               byte_index = byte_index+1)
	            if (S_AXI_WSTRB[byte_index] == 1'b1)
	              slv_reg4[(byte_index*8) +: 8] <=
	                S_AXI_WDATA[(byte_index*8) +: 8];
	        3'h5:
	          for (byte_index = 0;
	               byte_index <= (C_S_AXI_DATA_WIDTH/8)-1;
	               byte_index = byte_index+1)
	            if (S_AXI_WSTRB[byte_index] == 1'b1)
	              slv_reg5[(byte_index*8) +: 8] <=
	                S_AXI_WDATA[(byte_index*8) +: 8];
	        3'h6:
	          for (byte_index = 0;
	               byte_index <= (C_S_AXI_DATA_WIDTH/8)-1;
	               byte_index = byte_index+1)
	            if (S_AXI_WSTRB[byte_index] == 1'b1)
	              slv_reg6[(byte_index*8) +: 8] <=
	                S_AXI_WDATA[(byte_index*8) +: 8];
	        default: ;
	      endcase
	    end
	end

	// Implement read state machine
	  always @(posedge S_AXI_ACLK)
	    begin
	      if (S_AXI_ARESETN == 1'b0)
	        begin
	         //asserting initial values to all 0's during reset
	         axi_arready <= 1'b0;
	         axi_rvalid <= 1'b0;
	         axi_rresp <= 1'b0;
	         state_read <= Idle;
	        end
	      else
	        begin
	          case(state_read)
	            Idle:     //Initial state inidicating reset is done and ready to receive read/write transactions
	              begin
	                if (S_AXI_ARESETN == 1'b1)
	                  begin
	                    state_read <= Raddr;
	                    axi_arready <= 1'b1;
	                  end
	                else state_read <= state_read;
	              end
	            Raddr:        //At this state, slave is ready to receive address along with corresponding control signals
	              begin
	                if (S_AXI_ARVALID && S_AXI_ARREADY)
	                  begin
	                    state_read <= Rdata;
	                    axi_araddr <= S_AXI_ARADDR;
	                    axi_rvalid <= 1'b1;
	                    axi_arready <= 1'b0;
	                  end
	                else state_read <= state_read;
	              end
	            Rdata:        //At this state, slave is ready to send the data packets until the number of transfers is equal to burst length
	              begin
	                if (S_AXI_RVALID && S_AXI_RREADY)
	                  begin
	                    axi_rvalid <= 1'b0;
	                    axi_arready <= 1'b1;
	                    state_read <= Raddr;
	                  end
	                else state_read <= state_read;
	              end
	           endcase
	          end
	        end
	// Implement memory mapped register select and read logic generation
	always @(*)
	begin
	  case (read_reg_index)
	    3'h0: read_data_mux = {30'd0, slv_reg0[1:0]};
	    3'h1: read_data_mux = {28'd0,
	                            status_rejected_write,
	                            status_output_valid,
	                            status_busy,
	                            status_input_ready};
	    3'h2: read_data_mux = 32'd0;
	    3'h3: read_data_mux = {{16{audio_out_data[15]}},
	                            audio_out_data};
	    3'h4: read_data_mux = {16'd0, slv_reg4[15:0]};
	    3'h5: read_data_mux = {24'd0, slv_reg5[7:0]};
	    3'h6: read_data_mux = {23'd0, slv_reg6[8:0]};
	    3'h7: read_data_mux = 32'h0001_0000;
	    default: read_data_mux = 32'd0;
	  endcase
	end

	assign S_AXI_RDATA = read_data_mux;
	// Add user logic here
	assign cfg_mode          = slv_reg0[1:0];
	assign cfg_delay_samples = slv_reg4[15:0];
	assign cfg_feedback_q8   = slv_reg5[7:0];
	assign cfg_volume_q8     = slv_reg6[8:0];

	assign audio_in_wr_data = S_AXI_WDATA[15:0];
	assign audio_in_wr_strb_ok = S_AXI_WSTRB[0] && S_AXI_WSTRB[1];
	assign audio_in_wr_pulse = write_commit &&
	                           (write_reg_index == 3'h2);

	assign clear_error_pulse = write_commit &&
	                           (write_reg_index == 3'h0) &&
	                           S_AXI_WSTRB[1] && S_AXI_WDATA[8];

	assign audio_out_rd_pulse = read_commit &&
	                            (read_reg_index == 3'h3);
	// User logic ends

	endmodule
