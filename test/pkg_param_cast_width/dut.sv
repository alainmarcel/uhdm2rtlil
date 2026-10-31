// A SIZE CAST whose width is a package parameter, inside a package
// parameter's assignment pattern, referenced from ANOTHER module's parameter
// default:
//
//   package kmac_pkg;
//     parameter int unsigned NSPrefixW = sha3_pkg::NSRegisterSize*8;
//     parameter app_config_t AppCfgLcCtrl = '{
//       prefix: NSPrefixW'({EncodedStringLcCtrl, EncodedStringEmpty}), ... };
//   module earlgrey_pd_main #(parameter kmac_pkg::app_config_t
//     KmacAppCfg[KmacNumAppIntf] = '{kmac_pkg::AppCfgLcCtrl, ...});
//
// `package_parameter_map` held `NSPrefixW` ONLY under its qualified
// `kmac_pkg::NSPrefixW` spelling, while this reference is BARE -- it is
// imported outside its own package, re-evaluated in the scope of the module
// that names the parameter (and in the throwaway module
// import_module_hierarchy folds a paramod signature in).  The bare-name
// lookup missed, the reference fell through to the unknown-signal fallback,
// and the CAST produced NOTHING: `prefix` came out ZERO where read_slang
// carries the 88-bit encoded strings.
//
// Unlike the other two unknown-signal classes fixed alongside it (`$bits` of a
// module-local typedef, and a for-loop variable used as an index), this one is
// NOT just a noisy warning -- the VALUE was wrong.  In OpenTitan's
// top_earlgrey it silently blanked the compile-time cSHAKE / KMAC
// domain-separation prefix of every static KMAC application interface
// (KeyMgr, LC_CTRL, ROM_CTRL, OTBN).
//
// Reproducing it needed FAITHFULNESS to the real struct: three simpler
// attempts (the parameter in a width; a package struct as a variable type; a
// package-struct-typed unpacked-array parameter) all resolved correctly.  The
// ENUM members and the NESTED struct are what make the cast's typespec take
// the failing path.
package sha3_pkg;
  parameter int NSRegisterSize = 32;
  typedef enum logic [2:0] { L128 = 3'd0, L256 = 3'd2 } keccak_strength_e;
endpackage

package kmac_pkg;
  parameter int unsigned NSPrefixW = sha3_pkg::NSRegisterSize*8;   // 256
  parameter logic [71:0] EncodedStringLcCtrl  = 72'h4c_5254_435f_434C_3801;
  parameter logic [15:0] EncodedStringEmpty   = 16'h0001;
  typedef enum logic [1:0] { AppKMAC = 2'd0, AppCShake = 2'd1 } app_mode_e;
  typedef enum logic { AppStatic = 1'b0, AppDynamic = 1'b1 } app_if_e;

  typedef struct packed {
    logic                       prefix_mode;
    app_mode_e                  mode;
    sha3_pkg::keccak_strength_e kstrength;
    logic                       en_xof;
  } app_ses_config_t;

  typedef struct packed {
    app_if_e              if_type;
    logic                 masked;
    logic [NSPrefixW-1:0] prefix;
    logic                 en_unsup_comb;
    app_ses_config_t      session_cfg;
  } app_config_t;

  parameter app_config_t AppCfgLcCtrl = '{
    if_type:       AppStatic,
    masked:        1'b0,
    prefix:        NSPrefixW'({EncodedStringLcCtrl, EncodedStringEmpty}),
    en_unsup_comb: 1'b0,
    session_cfg: '{
      prefix_mode: 1'b1,
      mode:        AppCShake,
      kstrength:   sha3_pkg::L256,
      en_xof:      1'b0
    }
  };
endpackage

module pd #(parameter int KmacNumAppIntf = 1,
            parameter kmac_pkg::app_config_t KmacAppCfg[KmacNumAppIntf] =
              '{kmac_pkg::AppCfgLcCtrl})
  (output logic [263:0] o);
  assign o = KmacAppCfg[0];
endmodule

module dut(output logic [263:0] o);
  pd u (.o(o));
endmodule
