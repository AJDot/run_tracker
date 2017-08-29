--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.8
-- Dumped by pg_dump version 9.5.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: runs; Type: TABLE; Schema: public; Owner: ajdot
--

CREATE TABLE runs (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    distance numeric(6,2) NOT NULL,
    duration interval NOT NULL,
    date date NOT NULL,
    "time" time without time zone NOT NULL,
    user_id integer NOT NULL,
    CONSTRAINT runs_distance_check CHECK ((distance > 0.0))
);


ALTER TABLE runs OWNER TO ajdot;

--
-- Name: runs_id_seq; Type: SEQUENCE; Schema: public; Owner: ajdot
--

CREATE SEQUENCE runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE runs_id_seq OWNER TO ajdot;

--
-- Name: runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ajdot
--

ALTER SEQUENCE runs_id_seq OWNED BY runs.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: ajdot
--

CREATE TABLE users (
    id integer NOT NULL,
    name text NOT NULL,
    password text NOT NULL
);


ALTER TABLE users OWNER TO ajdot;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: ajdot
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO ajdot;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ajdot
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ajdot
--

ALTER TABLE ONLY runs ALTER COLUMN id SET DEFAULT nextval('runs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ajdot
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Data for Name: runs; Type: TABLE DATA; Schema: public; Owner: ajdot
--

COPY runs (id, name, distance, duration, date, "time", user_id) FROM stdin;
\.


--
-- Name: runs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ajdot
--

SELECT pg_catalog.setval('runs_id_seq', 177, true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: ajdot
--

COPY users (id, name, password) FROM stdin;
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ajdot
--

SELECT pg_catalog.setval('users_id_seq', 5, true);


--
-- Name: runs_name_user_id_key; Type: CONSTRAINT; Schema: public; Owner: ajdot
--

ALTER TABLE ONLY runs
    ADD CONSTRAINT runs_name_user_id_key UNIQUE (name, user_id);


--
-- Name: runs_pkey; Type: CONSTRAINT; Schema: public; Owner: ajdot
--

ALTER TABLE ONLY runs
    ADD CONSTRAINT runs_pkey PRIMARY KEY (id);


--
-- Name: users_name_key; Type: CONSTRAINT; Schema: public; Owner: ajdot
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_name_key UNIQUE (name);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: ajdot
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: runs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ajdot
--

ALTER TABLE ONLY runs
    ADD CONSTRAINT runs_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

