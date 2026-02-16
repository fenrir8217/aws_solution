package com.demo.svca;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

@SpringBootApplication
@EnableCaching
public class SvcAApplication {

    public static void main(String[] args) {
        SpringApplication.run(SvcAApplication.class, args);
    }
}
