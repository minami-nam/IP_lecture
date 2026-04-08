package hazard_package_list;

    typedef struct packed {
        logic [4:0] Rs1D;
        logic [4:0] Rs2D;
        logic [4:0] Rs1E;
        logic [4:0] Rs2E;

        logic [4:0] RdE;
        logic [4:0] RdM;
        logic [4:0] RdW;
    } input_reg_list;

    typedef struct packed {
        logic ZeroE;
        logic JumpE;
        logic BranchE;
        logic ResultSrcE;
        logic RegWriteM;
        logic RegWriteW; 
    } input_ctl_list;



endpackage