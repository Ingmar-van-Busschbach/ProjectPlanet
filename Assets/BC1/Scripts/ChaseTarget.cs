using System.Collections;
using System.Collections.Generic;
using UnityEngine;



public class ChaseTarget : MonoBehaviour
{
	public Transform target;
	public float visionAngle=45;
	public float chaseRange=5;
	public float turnSpeedDegreesSecond;
	public float moveSpeedPerSecond;
	public MeshRenderer eye;


    void Start()
    {
		SetEyeColor(true);
	}

	void SetEyeColor(bool enabled) {
		if (enabled) {
			eye.material.EnableKeyword("_EMISSION");
		} else {
			eye.material.DisableKeyword("_EMISSION");
		}
	}


	void Update()
    {
		// TODO: 
		//  - Make the enemy chase the player (target)
		//  - Make the enemy (slowly) rotate towards the player
		//  - Only do this when the player is in range (max distance) and in sight (max angle)
		//  - Draw rays in the scene view to indicate the vision range.
		// See the slides for details!
		// (You can use SetEyeColor for visual debugging)

		bool canChase = CheckDistanceAndLineOfSight();
		SetEyeColor(canChase);
        if (canChase)
		{
			//Turn
			Quaternion lookDirection = Quaternion.LookRotation(target.position - transform.position, Vector3.up);
			transform.rotation = Quaternion.RotateTowards(transform.rotation, lookDirection, turnSpeedDegreesSecond * Time.deltaTime);

			//Move
            Vector3 moveDirection = (target.position - transform.position).normalized;
            transform.position = transform.position + moveDirection * moveSpeedPerSecond * Time.deltaTime;
        }
	}

    private bool CheckDistanceAndLineOfSight()
	{
		return (target.position - transform.position).magnitude < chaseRange && Quaternion.Angle(transform.rotation, Quaternion.LookRotation(target.position - transform.position, Vector3.up)) < visionAngle;
	}
}
