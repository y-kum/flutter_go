module default {
    type User {
        required property id -> uuid;
        required property firstName -> str;
        required property lastName -> str;
        required property DOB -> datetime;
        required property email -> str;
        required property phoneNumber -> str;
        required property CVFileName -> str;  # Updated property name
    }
};
