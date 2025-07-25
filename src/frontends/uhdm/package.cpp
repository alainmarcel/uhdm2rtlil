/*
 * Package-specific UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog packages including
 * parameters, typespecs, and other package contents.
 */

#include "uhdm2rtlil.h"
#include <uhdm/vpi_visitor.h>
#include <uhdm/struct_typespec.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import a SystemVerilog package
void UhdmImporter::import_package(const package* uhdm_package) {
    if (!uhdm_package) return;
    
    std::string package_name = std::string(uhdm_package->VpiDefName());
    
    // Remove work@ prefix if present
    if (package_name.find("work@") == 0) {
        package_name = package_name.substr(5);
    }
    
    log("UHDM: Importing package: %s\n", package_name.c_str());
    
    // Store package for later reference
    package_map[package_name] = uhdm_package;
    
    // Import package parameters
    if (uhdm_package->Parameters()) {
        log("UHDM: Found %d parameters in package %s\n", 
            (int)uhdm_package->Parameters()->size(), package_name.c_str());
        
        for (const any* param : *uhdm_package->Parameters()) {
            if (auto param_obj = dynamic_cast<const parameter*>(param)) {
                std::string param_name = std::string(param_obj->VpiName());
                std::string full_name = package_name + "::" + param_name;
                
                log("UHDM: Importing package parameter: %s\n", full_name.c_str());
                
                // Get parameter value
                if (auto expr = param_obj->Expr()) {
                    // Temporarily set module to nullptr since we're in package context
                    RTLIL::Module* saved_module = module;
                    module = nullptr;
                    
                    RTLIL::SigSpec value_spec = import_expression(expr);
                    
                    module = saved_module;
                    
                    if (value_spec.is_fully_const()) {
                        RTLIL::Const param_value = value_spec.as_const();
                        package_parameter_map[full_name] = param_value;
                        log("UHDM: Package parameter %s = %s\n", 
                            full_name.c_str(), param_value.as_string().c_str());
                    } else {
                        log_warning("UHDM: Package parameter %s has non-constant value\n", 
                                   full_name.c_str());
                    }
                } else {
                    log_warning("UHDM: Package parameter %s has no expression\n", 
                               full_name.c_str());
                }
            }
        }
    }
    
    // Import package typespecs
    if (uhdm_package->Typespecs()) {
        log("UHDM: Found %d typespecs in package %s\n", 
            (int)uhdm_package->Typespecs()->size(), package_name.c_str());
        
        for (const typespec* ts : *uhdm_package->Typespecs()) {
            std::string type_name = std::string(ts->VpiName());
            std::string full_name = package_name + "::" + type_name;
            
            log("UHDM: Importing package typespec: %s (UhdmType=%d)\n", 
                full_name.c_str(), ts->UhdmType());
            
            // Store typespec for later reference
            package_typespec_map[full_name] = ts;
            
            // Also store without package prefix for import * cases
            package_typespec_map[type_name] = ts;
        }
    }
    
    // Import package variables (if any)
    if (uhdm_package->Variables()) {
        log("UHDM: Found %d variables in package %s\n", 
            (int)uhdm_package->Variables()->size(), package_name.c_str());
        
        // Note: Package variables are not commonly used in synthesizable code
        // but we log them for completeness
        for (const variables* var : *uhdm_package->Variables()) {
            std::string var_name = std::string(var->VpiName());
            log("UHDM: Package variable: %s (not imported - synthesis limitation)\n", 
                var_name.c_str());
        }
    }
    
    log("UHDM: Finished importing package %s\n", package_name.c_str());
}

YOSYS_NAMESPACE_END