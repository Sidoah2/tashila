.PHONY: sim sim-small

sim:
	python -m scripts.simulate.run_simulation

sim-small:
	SIM_NUM_CLIENTS=5 SIM_NUM_DRIVERS=3 SIM_TRIP_CYCLES=1 python -m scripts.simulate.run_simulation
