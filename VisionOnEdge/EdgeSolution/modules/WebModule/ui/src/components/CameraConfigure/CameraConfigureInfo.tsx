import React, { useEffect, FC } from 'react';
import { Flex, Text, Status, Button, Loader, Grid } from '@fluentui/react-northstar';
import { Link, useHistory } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';

import { useInterval } from '../../hooks/useInterval';
import {
  thunkDeleteProject,
  thunkGetTrainingStatus,
  thunkGetProject,
} from '../../store/project/projectActions';
import { Project } from '../../store/project/projectTypes';
import { State } from '../../store/State';
import { Camera } from '../../store/camera/cameraTypes';
import { RTSPVideo } from '../RTSPVideo';
import { useParts } from '../../hooks/useParts';
import { useQuery } from '../../hooks/useQuery';

export const CameraConfigureInfo: React.FC<{ camera: Camera; projectId: number }> = ({
  camera,
  projectId,
}) => {
  const { isLoading, error, data: project, trainingStatus } = useSelector<State, Project>(
    (state) => state.project,
  );
  const parts = useParts();
  const dispatch = useDispatch();
  const name = useQuery().get('name');
  const history = useHistory();

  const onDeleteConfigure = (): void => {
    // eslint-disable-next-line no-restricted-globals
    const sureDelete = confirm('Delete this configuration?');
    if (!sureDelete) return;
    const result = (dispatch(thunkDeleteProject(projectId)) as unknown) as Promise<any>;
    result
      .then((data) => {
        if (data) return history.push(`/cameras/detail?name=${name}`);
        return void 0;
      })
      .catch((err) => console.error(err));
  };

  /**
   * Call custom Vision to export
   */
  useEffect(() => {
    dispatch(thunkGetTrainingStatus(projectId));
  }, [dispatch, projectId]);
  useInterval(() => {
    dispatch(thunkGetTrainingStatus(projectId));
  }, 5000);

  useEffect(() => {
    dispatch(thunkGetProject());
  }, [dispatch]);

  return (
    <Flex column gap="gap.large">
      <h1>Configuration</h1>
      {trainingStatus ? (
        <Loader
          size="largest"
          label={trainingStatus}
          labelPosition="below"
          design={{ paddingTop: '300px' }}
        />
      ) : (
        <>
          <ListItem title="Status" content={<CameraStatus online={project.status === 'online'} />} />
          <ListItem
            title="Configured for"
            content={parts
              .filter((e) => project.parts.includes(e.id))
              .map((e) => e.name)
              .join(', ')}
          />
          <Flex column gap="gap.small">
            <Text styles={{ width: '150px' }} size="large">
              Live View:
            </Text>
            <RTSPVideo selectedCamera={camera} partId={project.parts[0]} canCapture={false} />
          </Flex>
          <ListItem
            title="Success Rate"
            content={
              <Text styles={{ color: 'rgb(244, 152, 40)', fontWeight: 'bold' }} size="large">
                {`${project.successRate}%`}
              </Text>
            }
          />
          <ListItem title="Successful Inferences" content={project.successfulInferences} />
          <ListItem
            title="Unidentified Items"
            content={
              <>
                <Text styles={{ margin: '5px' }} size="large">
                  {project.unIdetifiedItems}
                </Text>
                <Button
                  content="Identify Manually"
                  primary
                  styles={{
                    backgroundColor: 'red',
                    marginLeft: '100px',
                    ':hover': {
                      backgroundColor: '#A72037',
                    },
                    ':active': {
                      backgroundColor: '#8E192E',
                    },
                  }}
                  as={Link}
                  to="/manual"
                />
              </>
            }
          />
          <ConsequenseInfo precision={project.precision} recall={project.recall} mAP={project.mAP} />
          <Button primary onClick={onDeleteConfigure}>
            Delete Configuration
          </Button>
          <Button primary as={Link} to="/partIdentification">
            Edit Configuration
          </Button>
        </>
      )}
    </Flex>
  );
};

interface ConsequenseInfoProps {
  precision: number;
  recall: number;
  mAP: number;
}
const ConsequenseInfo: FC<ConsequenseInfoProps> = ({ precision, recall, mAP }) => {
  return (
    <Grid columns={3} >
      <div style={{height: '5em', display: 'flex', flexFlow: 'column', justifyContent: 'space-between'}}>
        <Text align="center" size="large" weight="semibold">
          Precison
        </Text>
        <Text align="center" size="large" weight="semibold" styles={{ color: '#9a0089' }}>
          {precision}%
        </Text>
      </div>
      <div style={{height: '5em', display: 'flex', flexFlow: 'column', justifyContent: 'space-between'}}>
        <Text align="center" size="large" weight="semibold">
          Recall
        </Text>
        <Text align="center" size="large" weight="semibold" styles={{ color: '#0063b1' }}>
          {recall}%
        </Text>
      </div>
      <div style={{height: '5em', display: 'flex', flexFlow: 'column', justifyContent: 'space-between'}}>
        <Text align="center" size="large" weight="semibold">
          mAP
        </Text>
        <Text align="center" size="large" weight="semibold" styles={{ color: '#69c138' }}>
          {mAP}%
        </Text>
      </div>
    </Grid>
  );
};

const ListItem = ({ title, content }): JSX.Element => {
  const getContent = (): JSX.Element => {
    if (typeof content === 'string' || typeof content === 'number')
      return <Text size="large">{content}</Text>;
    return content;
  };

  return (
    <Flex vAlign="center">
      <Text styles={{ width: '200px' }} size="large">{`${title}: `}</Text>
      {getContent()}
    </Flex>
  );
};

const CameraStatus = ({ online }): JSX.Element => {
  const text = online ? 'Online' : 'Offline';
  const state = online ? 'success' : 'unknown';

  return (
    <Flex gap="gap.smaller" vAlign="center">
      <Status state={state} />
      <Text styles={{ margin: '5px' }} size="large">
        {text}
      </Text>
    </Flex>
  );
};
