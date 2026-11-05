package audio_fx_types_pkg;

    typedef enum logic [1:0] {
        FX_MODE_BYPASS      = 2'b00,
        FX_MODE_LOW_PASS    = 2'b01,
        FX_MODE_HARD_CLIP   = 2'b10,
        FX_MODE_BITCRUSHER  = 2'b11
    } audio_fx_mode_t;

    localparam int AUDIO_WIDTH = 16;
    localparam int VOLUME_WIDTH = 9;
    localparam logic [VOLUME_WIDTH-1:0] VOLUME_UNITY_Q8 = 9'd256;

endpackage
