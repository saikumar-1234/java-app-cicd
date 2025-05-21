package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

// Spring Boot application annotation
@SpringBootApplication
@RestController
public class DemoApplication {

    // Entry point for the application
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    // Simple REST endpoint
    @GetMapping("/hello")
    public String hello() {
        return "Hello from Spring Boot!";
    }
}