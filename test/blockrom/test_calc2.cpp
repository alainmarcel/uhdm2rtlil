#include <cstdio>
#include <cstdint>

int main() {
    // Try as signed
    int64_t j = 0xF4B1CA8127865242LL;  // This is negative when interpreted as signed
    
    printf("Initial j as signed: %lld, as unsigned: %llu\n", (long long)j, (unsigned long long)j);
    
    for (int i = 0; i <= 7; i++) {
        // Do signed multiplication
        int64_t mem_value = j * (int64_t)0x2545F4914F6CDD1DLL;
        uint8_t mem_byte = mem_value & 0xFF;
        
        printf("memory[%d] = 0x%02x (j=0x%016llx, full=0x%016llx)\n", 
               i, mem_byte, (unsigned long long)j, (unsigned long long)mem_value);
        
        // These operations should be done as unsigned
        uint64_t uj = (uint64_t)j;
        uj = uj ^ (uj >> 12);
        uj = uj ^ (uj << 25);
        uj = uj ^ (uj >> 27);
        j = (int64_t)uj;
    }
    
    return 0;
}